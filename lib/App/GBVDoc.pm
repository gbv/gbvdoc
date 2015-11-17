package App::GBVDoc;
use v5.14;

#ABSTRACT: GBV Linked Data Server http://uri.gbv.de/document/

use Log::Contextual qw(:log);
use RDF::Lazy qw(0.061);
use Plack::Request;

use RDF::Trine qw(iri);
use RDF::Trine::Model;
use RDF::Trine::Parser;

use RDF::NS;
our $NS = RDF::NS->new('20111102');

use RDF::Flow::Cascade;
use GBV::RDF::Source::Item;
use GBV::RDF::Source::Document;
use CHI;

use GBV::App::URI::Base qw(0.112);
use parent 'GBV::App::URI::Base';

sub init {
    my $self = shift;

    my $source = RDF::Flow::Cascade->new(
            GBV::RDF::Source::Item->new,
            GBV::RDF::Source::Document->new,
            name => "item-or-document"
        );
    $source = RDF::Flow::Cached->new(
        $source, 
        CHI->new( driver => 'Memory', global => 1, expires_in => '1 hour' ),
    );
    $self->source( $source );
}

sub core {
    my ($self, $app, $env) = @_;

    my $uri = $env->{'rdflow.uri'};
    my $rdf = $env->{'rdflow.data'};
    my $req = Plack::Request->new($env);

    if ( $rdf and $rdf->size ) {
        delete $NS->{uri}; # TODO: Bug in RDF::Lazy
        my $lazy = RDF::Lazy->new( $rdf, namespaces => $NS );
        $env->{'tt.vars'}->{uri} = $lazy->resource($uri);

        if ( $uri eq $self->base ) {
            # main page
        } else {
            $env->{'tt.path'} = '/document.html';
        }
    }

    $env->{'tt.vars'}->{apptitle}  = 'Documents in libraries';
    $env->{'tt.vars'}->{error}     = $env->{'rdflow.error'};
    $env->{'tt.vars'}->{timestamp} = $env->{'rdflow.timestamp'};
    $env->{'tt.vars'}->{cached} = 1 if $env->{'rdflow.cached'};
}

1;
