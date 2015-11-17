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

use Plack::Builder;

use parent 'Plack::Component';
use Plack::Util::Accessor qw(source base formats);

use RDF::NS;
our $NS = RDF::NS->new('20111102');

use Plack::Middleware::TemplateToolkit;
use Plack::Middleware::RDF::Flow qw(0.170);
use Try::Tiny;
use CHI;

our %FORMATS = (
    nt   => 'ntriples', 
    rdf  => 'rdfxml', 
    xml  => 'rdfxml',
    ttl  => 'turtle',
    json => 'rdfjson',
);

sub core {
    my ($self, $app, $env) = @_;

    if ( ($env->{'HTTP_X_FORWARDED_HOST'} || '') eq 'uri.gbv.de' ) {
        my $base = $self->base;
        $base =~ s{^http://uri.gbv.de/|/$}{}g;
        $env->{'SCRIPT_NAME'} = "/$base/" . ($env->{'SCRIPT_NAME'}|'');
    #   $env->{'PATH_INFO'} = "/$base" . $env->{'PATH_INFO'};
        $env->{'REQUEST_URI'} = "/$base" . $env->{'REQUEST_URI'};
    }

    my $uri = $env->{'rdflow.uri'};

    $env->{'tt.vars'} = { } unless $env->{'tt.vars'};
    $env->{'tt.vars'}->{'uri'} = $uri;
    $env->{'tt.vars'}->{'formats'} = [ @{$self->formats} ];

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

    $app->($env);
}

sub prepare_app {
    my $self = shift;
    return if $self->{app};

    delete $NS->{uri};
    $self->base('http://uri.gbv.de/document/');

    $self->formats([qw(ttl json rdfxml)])
        unless $self->formats;

    # init
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

    $self->{app} = builder {
        enable 'Static', 
            root => 'public',
            path => qr{\.(css|png|gif|js|ico)$};

        # cache everything else for 10 seconds. TODO: set cache time
        enable 'Cached',
                cache => CHI->new( 
                    driver => 'Memory', global => 1, 
                    expires_in => '10 seconds' 
                );

        enable 'JSONP';
        enable 'RDF::Flow',
            base         => $self->base,
            empty_base   => 1,
            source       => $self->source,
            pass_through => 1,
            formats      => \%FORMATS;

        # core driver
        enable sub { 
            my $app = shift;
            sub { 
                my $env = shift;
                $self->core($app, $env);
            },
        };
    
        Plack::Middleware::TemplateToolkit->new( 
            INCLUDE_PATH => 'public',
            RELATIVE => 1, # ??
            INTERPOLATE => 1, 
            pass_through => 0,
#            timer => $is_devel,
            request_vars => [qw(base)],
            404 => '404.html', 500 => '500.html'
        );
    };
}

sub call {
    my ($self, $env) = @_;
    $self->{app}->($env);
}

1;
