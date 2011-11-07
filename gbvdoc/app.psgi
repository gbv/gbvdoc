use strict;
use warnings;

use File::Spec::Functions qw(catdir rel2abs);
use File::Basename qw(dirname);
use lib rel2abs(catdir(dirname($0),'lib'));

use Plack::Builder;
use GBV::App::URI::Document;

my $env = $ENV{PLACK_ENV} || "deployment";
my $root = rel2abs(catdir(dirname($0),'htdocs'));

my $app  = GBV::App::URI::Document->new;

builder {

    # Show server status at http://uri.gbv.de/document/_status
    enable 'ServerStatus::Lite',
        path => '/_status',
        scoreboard => '/tmp/gbvdoc-scoreboard';

    enable_if { $env eq 'debug' } 'AccessLog';
    enable_if { $env eq 'debug' } 'StackTrace';
    enable_if { $env eq 'debug' } 'Lint';
    enable_if { $env eq "debug" } "Debug";

    enable "SimpleLogger";
    enable_if { $env eq 'debug' } "Log::Contextual", level => 'trace';
    enable_if { $env ne 'debug' } "Log::Contextual", level => 'warn';

    enable 'Runtime'; # add X-Runtime header

    enable 'Static',
            path => qr{\.(gif|png|jpg|ico|js|css|xsl)$},
            root => $root;

    enable 'Plack::Middleware::TemplateToolkit',
        INCLUDE_PATH => $root,
        pass_through => 1;

    enable 'JSONP';
    $app;
}
