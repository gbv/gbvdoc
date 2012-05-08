use strict;
use warnings;

# get absolute path and local libraries
use File::Spec::Functions qw(catdir rel2abs);
use File::Basename qw(dirname);
use lib rel2abs(catdir(dirname($0),'lib'));

use Log::Contextual qw(:log);
use RDF::Trine;
BEGIN { # remove support of RDFa by force!
    foreach my $type (qw(application/xhtml+xml text/html)) {
        delete $RDF::Trine::Parser::media_types{ $type };
    }
}

my $root = rel2abs(dirname($0));

use Plack::Builder;
use GBV::App::URI::Document;

sub is_devel { ($ENV{PLACK_ENV}||'') eq 'development' }

builder {
    enable_if { is_devel } 'Debug';
    enable_if { is_devel } 'Debug::TemplateToolkit';
    enable_if { is_devel } 'ConsoleLogger';
    enable_if { !is_devel } 'SimpleLogger';
    enable_if { is_devel } 'Log::Contextual', level => 'trace';
    enable_if { !is_devel } 'Log::Contextual', level => 'warn';

    GBV::App::URI::Document->new( htdocs => catdir($root,'htdocs') );
};
