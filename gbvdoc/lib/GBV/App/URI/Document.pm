use strict;
use warnings;
package GBV::App::URI::Document;
#ABSTRACT: GBV Linked Data Server http://uri.gbv.de/document/

use Log::Contextual qw(:log);

use parent 'Plack::Component';

use RDF::Flow::LinkedData;
use RDF::Trine qw(iri);
use RDF::NS::Trine;
use LWP::Simple qw(get);
use PICA::Record;
use RDF::Dumper;
use Data::Dumper;
use Encode qw(encode);

our $WEB = RDF::Flow::LinkedData->new( name => 'Semantic Web' );
our $NS  = RDF::NS::Trine->new('20111031');

BEGIN { 
    # remove support of RDFa by force! (RDF::Trine <= 0.132)
    foreach my $type (qw(application/xhtml+xml text/html)) {
        delete $RDF::Trine::Parser::media_types{ $type };
    }
}

sub prepare_app {
    my ($self) = @_;

    # TODO: caching?
}

sub call {
    my $self = shift;
    my $req = Plack::Request->new(shift);

    my $status = 200;
    my $type = "text/html; charset=utf-8";
    my $content = "Hello!";

    return [ $status, [ "Content-Type" => $type ], [ encode('utf8',$content) ] ];
}

1;
