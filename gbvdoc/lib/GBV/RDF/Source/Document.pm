use strict;
use warnings;
package GBV::RDF::Source::Document;
#ABSTRACT: Edition or work from http://uri.gbv.de/document/

use Log::Contextual qw(:log); #, -default_logger

use RDF::NS::Trine;
our $NS = RDF::NS::Trine->new('20111124');

use RDF::Trine qw(statement iri literal blank);
use RDF::Trine::Model;
use RDF::Flow qw(0.173);
use RDF::Flow::Source qw(empty_rdf);
use GBV::RDF::Source::Item;

use parent 'RDF::Flow::Source';

use LWP::Simple qw(get);
use PICA::Field;
use RDF::Flow::LinkedData;

our $databases = RDF::Flow::LinkedData->new(
    name  => 'GBV databases',
    match => qr{^http://uri\.gbv\.de/database/[a-zA-Z0-9:/-]+$}
);
our $b3kat = RDF::Flow::LinkedData->new(
    name  => 'B3Kat',
    match => qr{^http://lod\.b3kat\.de/}
);


sub retrieve_rdf {
    my ($self, $env) = @_;

    my $uri = $env->{'rdflow.uri'};
    return unless $uri =~ qr{^http://uri\.gbv\.de/document/([a-zA-Z0-9:/-]+):ppn:([0-9Xx]+)$};
    my ($dbkey, $ppn) = ($1, $2);

    my $dburi = "http://uri.gbv.de/database/$dbkey";
    my $db = $databases->retrieve( $dburi );
    return if empty_rdf($db);
    
    my $rdf = RDF::Trine::Model->new;
    my @triples;

    push @triples,
        [ iri($uri), $NS->rdf('type'), $NS->bibo_Document ],
    ;

    my $pica;
    my $picabase =  $db->objects( iri($dburi), $NS->gbv('picabase') )->next;
    if ($picabase) {
        my $url = "http://unapi.gbv.de/?id=$dbkey:ppn:$ppn&format=pp";
        $pica = eval { PICA::Record->new( get($url)) };
    }

    if ($pica) {
        my $org = $db->subjects( $NS->gbv_opac, iri($dburi) )->next;
        push @triples, $self->pica_data( $uri, $pica, $picabase, $dbkey, $org );
    } else {
#        log_warn { "No pica data: $dbkey:ppn:$ppn" };
    }

    $rdf->add_statement( statement( @$_ ) ) for @triples;

    return $rdf;
}

sub pica_data {
    my ($self, $uri, $pica, $picabase, $dbkey, $org) = @_;
    my @triples;

    return unless $pica;

    if ($picabase) {
        my $url = $picabase->uri . "PPNSET?PPN=" . $pica->ppn;
        push @triples, [ iri($uri), $NS->foaf_page, iri($url) ];
    }
    push @triples, [ iri($uri), $NS->daia_collectedBy, $org ] if $org;
 
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
        push @triples, [ iri($uri), $NS->URI($p), $NS->URI($o) ] 
            if $NS->URI($p) and $NS->URI($o);
    }

    # Titel
    my $title = $pica->sf('021A$a');
    if ($title) {
        $title =~ s/ @/ /;
        push @triples, [ iri($uri), $NS->dc('title'), literal($title) ];
    }

    my @items;
    if ($dbkey and $org) {
        @items = $pica->items;
        # TODO: nur die mit passender ILN rausnehmen!

        my $itemsource = GBV::RDF::Source::Item->new;

        foreach my $item (@items) {
            my $data = { liburi => $org, picabase => $picabase };
            my $itemuri = "http://uri.gbv.de/document/" . $dbkey . ':epn:' . $item->epn;
            push @triples, $itemsource->picaitem_to_triples( $itemuri => $item, $data );
            push @triples, [ iri($uri), $NS->daia_exemplar, iri($itemuri) ];
        }
    }


    my $eki = $pica->field('007G');
    $eki = join '', $eki->sf('c','0') if $eki;
    if ($eki and $eki =~ /^BVB(BV\d+)$/) {
        my $url = "http://lod.b3kat.de/title/$1";
        my $b3 = $b3kat->retrieve($url);
        if (!empty_rdf($b3)) {
            if( $b3->isa('RDF::Trine::Iterator') ) {
                my $m = RDF::Trine::Model->new;
                $m->add_iterator($b3);
                $b3 = $m;
            }
            my $btitle = $b3->objects( iri($url), $NS->dc_title )->next;
            if ($btitle and $btitle->value eq $title) {
                push @triples, [ iri($uri), $NS->owl_sameAs, iri($url) ];
                my $match = $b3->objects( iri($url), $NS->frbr_exemplar );
                while (my $row = $match->next) {
                    push @triples, [ iri($uri), $NS->daia_exemplar, $row ];
                }
            }
        }
        push @triples, [ iri($uri), $NS->daia_eki, iri($url) ];
    }

    return @triples;
}


1;
