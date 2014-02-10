use v5.14.2;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Plack::Builder;
use GBV::App::URI::Document;

my $devel = ($ENV{PLACK_ENV}||'') eq 'development'; 

builder {
    enable_if { $devel } 'Debug';
    enable_if { $devel } 'Debug::TemplateToolkit';
    enable_if { $devel } 'SimpleLogger';
    enable_if { $devel } 'Log::Contextual', level => 'trace';

    GBV::App::URI::Document->new(
        root   => 'public',
#        config => rel2abs(catdir(dirname($0),'libsites-config')),
    );
};
