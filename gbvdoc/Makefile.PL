#!/usr/bin/env perl
use ExtUtils::MakeMaker;
WriteMakefile(
    PREREQ_PM => {
        'Plack::Request' => '0.9976',

        'Plack::Middleware::TemplateToolkit' => '0.2',
        'Plack::Middleware::Log::Contextual' => '0.01',
        'Plack::Middleware::ConsoleLogger'   => 0,
        'Plack::Middleware::ServerStatus::Lite' => '0.01',
        'Plack::Middleware::RDF::Flow' => '0.01',
        'Plack::Middleware::Cached' => '0.01',
#        'RDF::Trine::Exporter::GraphViz' => '0',
        'Log::Contextual' => 0,

        'RDF::Flow::LinkedData' => '0',
        'RDF::NS'        => '20111102',
        'RDF::Lazy'        => '0',
        'PICA::Record'   => '0.56',
        'LWP::Simple'    => 0,
        'CHI'       => 0,
        'Try::Tiny' => 0,

        'RDF::Trine'    => 0.136,

        'Encode'        => 0,
        'RDF::Dumper'   => 0,
        'Data::Dumper' => 0,
    },
);
