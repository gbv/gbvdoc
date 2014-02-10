use strict;
use warnings;
package GBV::App::URI::Base;
#ABSTRACT: Common base class of Linked Data applications at http://uri.gbv.de/

our $VERSION = '0.115';

use Plack::Builder;

use parent 'Plack::Component', 'Exporter';
use Plack::Util::Accessor qw(root source base share rewrite_uri formats);

use RDF::NS;
our $NS;
BEGIN {
    $NS = RDF::NS->new('20111102');
}

use File::ShareDir;
use Plack::Middleware::TemplateToolkit;
use Plack::Middleware::RDF::Flow qw(0.170);
use Try::Tiny;
use CHI;

# if RDF::Trine::Exporter::GraphViz is installed, provide graphical RDF
our %FORMATS;
BEGIN {
    %FORMATS = (
        nt   => 'ntriples', 
        rdf  => 'rdfxml', 
        xml  => 'rdfxml',
        ttl  => 'turtle',
        json => 'rdfjson',
    );
    eval "use RDF::Trine::Exporter::GraphViz;";
    unless ($@) {
        foreach (qw(svg png dot)) {
            $FORMATS{$_} = RDF::Trine::Exporter::GraphViz->new( 
                as => $_, namespaces => $NS );
        }
    }
}

sub prepare_app {
    my $self = shift;
    return if $self->{app};

    delete $NS->{uri};

    my $base = ref($self);
    if ( $base =~ /^GBV::App::URI::(.+)$/ and $1 ne 'Base' ) {
        $base = "http://uri.gbv.de/" . lc($1) . '/';
        $base =~ s/::/\//g;
        $self->base( $base );
    } else {
        $self->base('http://uri.gbv.de/');
    }

    # Enable share dir before all other root
    # To test this module do a symlink from root to share
    $self->share( try { File::ShareDir::dist_dir('GBV-App-URI-Base') } || 'share' )
        unless $self->share;

    my $root = $self->root ? [ $self->share, $self->root ] : $self->root;
 
    $self->formats([qw(ttl json rdfxml)])
        unless $self->formats;

    $self->init;

    $self->{app} = builder {
        enable 'Static', 
            root => $self->share, pass_through => 1,
            path => qr{\.(css|png|gif|js|ico)$};

        enable 'Static', 
            root => $self->root, 
            path => qr{\.(css|png|gif|js|ico)$};

        # TODO: serve static files via templates?

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
            rewrite      => $self->rewrite_uri,
            source       => $self->source,
            pass_through => 1,
            formats      => \%FORMATS;

        # core driver
        enable sub { 
            my $app = shift;
            sub { 
                my $env = shift;
                $self->pre($env);
                $self->core($app, $env);
                $self->post($env);
                $app->($env);
            },
        };
    
        Plack::Middleware::TemplateToolkit->new( 
            INCLUDE_PATH => $root,
            RELATIVE => 1, # ??
            INTERPOLATE => 1, 
            pass_through => 0,
#            timer => $is_devel,
            request_vars => [qw(base)],
            404 => '404.html', 500 => '500.html'
        );
    };
}

sub init {
    my $self = shift;

    # called by prepare_app
    # implement this in your derived class, if needed
}

# called before the core
sub pre {
    my ($self, $env) = @_;

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
}

# called for each request, before the Template middleware
sub core {
    my ($self, $app, $env) = @_;
    # ...implement this in your derived class...
}

sub post {
    my ($self, $env) = @_;

    $env->{'tt.vars'}->{error}     = $env->{'rdflow.error'};
    $env->{'tt.vars'}->{timestamp} = $env->{'rdflow.timestamp'};
    $env->{'tt.vars'}->{cached} = 1 if $env->{'rdflow.cached'};
}

sub call { 
    my $self = shift;
    $self->{app}->( @_ );
}

1;
