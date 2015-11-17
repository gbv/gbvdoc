requires 'perl', '5.14.1';

requires 'Plack::Middleware::Negotiate', '0.06';
requires 'Plack::Middleware::TemplateToolkit', '0.25';
requires 'Plack::Middleware::Log::Contextual', '0.01';
requires 'Plack::Middleware::RDF::Flow', '0.01';
requires 'Plack::Middleware::Cached', '0.01';

requires 'RDF::aREF', '0.11';
requires 'RDF::Flow'    , '0.178';
requires 'RDF::Lazy'       , '0';
requires 'PICA::Record'  , '0.56';
requires 'LWP::Simple'   , 0;

# TODO: remove
requires 'Data::Dumper', 0;

# ??
requires 'XML::LibXML::Simple', '0.91';
requires 'HTTP::Tiny';

# requirments met by Debian packages
requires 'RDF::Trine';
requires 'RDF::NS', '20130930';
requires 'CHI';
requires 'JSON';
requires 'Log::Contextual', '0.006000';
requires 'Try::Tiny';

# test requirements
test_requires 'Plack::Util::Load'
