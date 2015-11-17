use v5.14.1;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Plack::Util::Load;
use JSON;

my $app = load_app($ENV{TEST_URL} // 'app.psgi');

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET "/");
    is $res->code, '200', 'base';

#    $res = $cb->(GET "/gvk");
#    is $res->code, '200', 'gvk found';

#    foreach my $format (qw(ttl rdfxml dbinfo ld json)) {
#        $res = $cb->(GET "/opac-de-ilm1?format=$format");
#        is $res->code, '200', "opac-de-ilm1 found (format=$format)";
#    }

};

done_testing;
