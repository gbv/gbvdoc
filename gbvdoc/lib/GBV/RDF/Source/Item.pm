use strict;
use warnings;
package GBV::RDF::Source::Item;
#ABSTRACT: Copy or exemplar in a library holding

use Log::Contextual qw(:log); #, -default_logger

use RDF::NS::Trine;
our $NS = RDF::NS::Trine->new('20111102');

use RDF::Trine qw(statement iri literal blank);
use RDF::Trine::Model;
use RDF::Flow qw(0.173);
use RDF::Flow::Source qw(empty_rdf);

use parent 'RDF::Flow::Source';

use LWP::Simple qw(get);
use PICA::Field;
use RDF::Flow::LinkedData;

our $opacdatabases = RDF::Flow::LinkedData->new(
    name  => 'OPAC databases',
    match => qr{^http://uri\.gbv\.de/database/opac-[a-zA-Z0-9:/-]+$}
);

sub retrieve_rdf {
    my ($self, $env) = @_;

    my $uri = $env->{'rdflow.uri'};
    return unless $uri =~ qr{^http://uri\.gbv\.de/document/(opac-[a-zA-Z0-9:/-]+):epn:(\d+)$};
    my ($isil, $epn) = ($1, $2);

    my $opacuri = "http://uri.gbv.de/database/$isil";
    my $opac = $opacdatabases->retrieve( $opacuri );
    return if empty_rdf($opac);
    
    my $rdf = RDF::Trine::Model->new;
    my @triples;

#    push @triples, [ iri($uri), iri('http://example.org/described-by-record-in-database'), iri($opacuri) ];

    my $liburi = $opac->subjects( $NS->gbv('opac'), iri($opacuri) )->next;
    if ($liburi) {
        push @triples, [ iri($uri), $NS->daia('heldBy'), $liburi ];

        my $library = RDF::Flow::LinkedData->new()->retrieve( $liburi->uri );
        my $iter = $library->get_statements( undef, $NS->foaf('name'), undef );
        while(my $st = $iter->next) {  $rdf->add_statement( $st ) } 
        $iter = $library->get_statements( undef, $NS->owl('sameAs'), undef );
        while(my $st = $iter->next) {  $rdf->add_statement( $st ) } 

        # my $iterator = $opac->as_stream;
        # while(my $row = $iterator->next) {  $rdf->add_statement( $row ) } 
    }

    my $pica;
    my $picabase =  $opac->objects( iri($opacuri), $NS->gbv('picabase') )->next;
    my $dbkey    = $opac->objects( iri($opacuri), $NS->gbv('dbkey') )->next;
    $dbkey = $dbkey->value if $dbkey;
    if ($picabase) {
        my $url = $picabase->uri . "CMD?ACT=SRCHA&IKT=1016&TRM=epn+$epn&XML=1.0";
        my $xml = get($url);
        if ($xml =~ /PPN="([0-9x]+)"/mi) {
            my $ppn = $1;
            $url = "http://unapi.gbv.de/?id=$dbkey:ppn:$ppn&format=pp";
            $pica = eval { PICA::Record->new( get($url)) };
        }
    }
    
    my ($item) = grep {  $_->epn eq $epn } $pica->items if $pica;
    return unless $item;

    # Dokumenttyp
    my @f002a = split //, $pica->sf('002@$0');
    my %materialarten = (
        A => [ { 'dcterms:format' => 'rdamedia:1007' } ], # Druckschrift
        B => [ { 'dcterms:format' => 'rdamedia:1008' } ], # audiovisuelles Material
        C => [ { 'dcterms:format' => 'rdamedia:1007' } ], # Blindenschriftträger 
        D => [ { 'dcterms:format' => 'rdamedia:1007' } ], # Briefe
        E => [ { 'dcterms:format' => 'rdamedia:1002' } ], # Mikroform
        G => [ { 'dcterms:format' => 'rdamedia:1001' } ], # Tonträger
        H => [ { 'dcterms:format' => 'rdamedia:1007' } ], # handschrifliches Material
        I => [ { 'dcterms:format' => 'rdamedia:1007' } ], # ill. Material
        K => [ { 'dcterms:format' => 'rdamedia:1007' } ], # Kartographisches Material
        M => [ { 'dcterms:format' => 'rdamedia:1007' } ], # Noten
        O => [ { 'dcterms:format' => 'rdamedia:1003' } ], # elektron. Material
        S => [ { 'dcterms:format' => 'rdamedia:1003' } ], # CD-ROM, Software
        V => [ { 'dcterms:format' => 'rdamedia:1007' } ], # Objekte
        Z => [ { 'dcterms:format' => 'rdamedia:1003' } ], # Multimedia
    );

    my $material = $materialarten{$f002a[0]};# or return;
    foreach (@$material) {
        my ($p,$o) = %$_;
        push @triples, [ iri($uri), $NS->uri($p), $NS->uri($o) ] if $NS->uri($p) and $NS->uri($o);
    }

    if ($picabase) {
        my $url = $picabase->uri . "CMD?ACT=SRCHA&IKT=1016&TRM=epn+$epn";
        push @triples, [ iri($uri), $NS->foaf('page'), iri($url) ];
    }

    my $f209A = $item->field('209A/..') || PICA::Field->new('209A');
    if ( my $label = $f209A->sf('a') ) {
        push @triples, [ iri($uri), $NS->daia('label'), literal($label) ];
    }

    # Standort
    if ( my $sst = $f209A->sf('f') ) {
        $sst = lc($sst);
        $sst =~ s/\s+/_/;
        my $ssturi;
        if ($liburi) {
            $ssturi = $liburi->uri . '@' . $sst;
            push @triples, [ iri($uri), $NS->dcterms('spatial'), iri($ssturi) ];
        }
    }

    # Titel
    if ( my $title = $pica->sf('021A$a') ) {
        $title =~ s/ @/ /;
        push @triples, [ iri($uri), $NS->dc('title'), literal($title) ];
    }

    # Ausleihindikator
    if ( my $d = $f209A->sf('d') ) {
        if ($d =~ /[aoz]/) {
            my $service = blank();
            push @triples,
                [ iri($uri), $NS->daia('unavailableFor'), $service ],
                [ $service, $NS->rdf('type'), $NS->daia('service/Presentation') ]
            ;
        }
        if ($d =~ /[ifaogz]/) {
            my $service = blank();
            push @triples,
                [ iri($uri), $NS->daia('unavailableFor'), $service ],
                [ $service, $NS->rdf('type'), $NS->daia('service/Loan') ]
            ;
        }
        if ($d =~ /[ciaogz]/) {
            my $service = blank();
            push @triples,
                [ iri($uri), $NS->daia('unavailableFor'), $service ],
                [ $service, $NS->rdf('type'), $NS->daia('service/Interloan') ]
            ;
        }
    }

    # Online-Zugriff
    my @online = $item->field('209R/..');
    foreach my $f (@online) {
        my $service = blank();
        my $url = $f->sf('a') or next;

        # Weitergabe erlaubt?
        my $license = $f->sf('S');
        next if defined $license and not $license;

        # Registrierung o.Ä. Einschränkung
        $license = $f->sf('4');
        next if defined $license and $license =~ /^(KF|KW|NL|PU|ZZ)$/;

        push @triples,
            [ iri($uri), $NS->daia('availableFor'), $service ],
            [ $service, $NS->rdf('type'), $NS->daia('service/Openaccess') ],
            [ $service, $NS->foaf('page'), iri($url) ],
        ;
    }

    # TODO: Lizenzbedingungen: 209W
    # Beispiel: opac-de-7:epn:123872275X (CC-BY-NC-ND)

    # Provenienz?!
    #  244Z Lokale Schlagworte


    push @triples,
        [ iri($uri), $NS->rdf('type'), $NS->frbr('Item') ],
    ;
    $rdf->add_statement( statement( @$_ ) ) for @triples;

    return $rdf;
}

# TODO: add to RDF::Trine
sub RDF::Trine::Model::add_iterator {
    my ($self, $iter) = @_;
    $self->begin_bulk_ops();
    while (my $st = $iter->next) {
        $self->add_statement( $st );
    }
    $self->end_bulk_ops();
}

1;
