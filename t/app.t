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

    my $doc = 'opac-de-960:ppn:02722807X';
    $res = $cb->(GET "/$doc");
    is $res->code, '200', "$doc found";

    foreach my $format (qw(ttl rdfxml json)) {
        $res = $cb->(GET "/$doc?format=$format");
        is $res->code, '200', "format=$format";
    }

    $doc = 'opac-de-960:epn:711201994';
    $res = $cb->(GET "/$doc");
    is $res->code, '200', "$doc found";
};

done_testing;
