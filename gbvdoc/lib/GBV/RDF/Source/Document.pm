use strict;
use warnings;
package GBV::RDF::Source::Document;
#ABSTRACT: Edition or work from http://uri.gbv.de/document/

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

our $databases = RDF::Flow::LinkedData->new(
    name  => 'GBV databases',
    match => qr{^http://uri\.gbv\.de/database/[a-zA-Z0-9:/-]+$}
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

    push @triples, $self->pica_data( $uri, $pica, $picabase ) if $pica;

    $rdf->add_statement( statement( @$_ ) ) for @triples;

    return $rdf;
}

sub pica_data {
    my ($self, $uri, $pica, $picabase) = @_;
    my @triples;

    return unless $pica;

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

    # Titel
    if ( my $title = $pica->sf('021A$a') ) {
        $title =~ s/ @/ /;
        push @triples, [ iri($uri), $NS->dc('title'), literal($title) ];
    }

    return @triples;
}


1;
