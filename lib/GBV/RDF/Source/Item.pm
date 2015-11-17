package GBV::RDF::Source::Item;
use v5.14;

#ABSTRACT: Copy or exemplar in a library holding

use Log::Contextual qw(:log); #, -default_logger

use RDF::NS::Trine;
our $NS = RDF::NS::Trine->new('20111102');

use RDF::Trine qw(statement iri literal blank);
use RDF::Trine::Model;
use RDF::Flow qw(0.173);
use RDF::Flow::Source qw(empty_rdf);

use parent 'RDF::Flow::Source';

use GBV::RDF::Source::Document;

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

    my $liburi = $opac->subjects( $NS->gbv_opac, iri($opacuri) )->next;
    if ($liburi) {
        push @triples, [ iri($uri), $NS->daia_heldBy, $liburi ];

        my $library = RDF::Flow::LinkedData->new()->retrieve( $liburi->uri );
        my $iter = $library->get_statements( undef, $NS->foaf_name, undef );
        while(my $st = $iter->next) {  $rdf->add_statement( $st ) } 
        $iter = $library->get_statements( undef, $NS->owl_sameAs, undef );
        while(my $st = $iter->next) {  $rdf->add_statement( $st ) } 

        # my $iterator = $opac->as_stream;
        # while(my $row = $iterator->next) {  $rdf->add_statement( $row ) } 
    }

    my $pica;
    my $picabase =  $opac->objects( iri($opacuri), $NS->gbv_picabase )->next;
    my $dbkey    = $opac->objects( iri($opacuri), $NS->gbv_dbkey )->next;
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
    
    return unless $pica;

    if ( $dbkey ) {
        my $docuri = "http://uri.gbv.de/document/$dbkey:ppn:" . $pica->ppn;
        push @triples, [ iri($uri), $NS->daia_exemplarOf, iri($docuri) ];
    }

    my ($item) = grep {  $_->epn eq $epn } $pica->items;
    return unless $item;

    push @triples, GBV::RDF::Source::Document->pica_data( $uri, $pica, $picabase );

    my $data = { liburi => $liburi, picabase => $picabase };
    push @triples, $self->picaitem_to_triples( $uri => $item, $data );

    $rdf->add_statement( statement( @$_ ) ) for @triples;

    return $rdf;
}

sub picaitem_to_triples {
    my ($self, $uri, $item, $data) = @_;
    my @triples;

    if ($data->{picabase}) {
        my $url = $data->{picabase}->uri . "CMD?ACT=SRCHA&IKT=1016&TRM=epn+" . $item->epn;
        push @triples, [ iri($uri), $NS->foaf_page, iri($url) ];
    }

    push @triples, [ iri($uri), $NS->rdf_type, $NS->frbr_Item ];

    my $f209A = $item->field('209A/..') || PICA::Field->new('209A');
    if ( my $label = $f209A->sf('a') ) {
        push @triples, [ iri($uri), $NS->daia_label, literal($label) ];
    }
 
    # Standort
    if ( my $sst = $f209A->sf('f') ) {
        $sst = lc($sst);
        $sst =~ s/\s+/_/;
        my $ssturi;
        if ($data->{liburi}) {
            $ssturi = $data->{liburi}->uri . '@' . $sst;
            push @triples, [ iri($uri), $NS->dcterms_spatial, iri($ssturi) ];
        }
    }

    return @triples
}

1;
