#!/usr/bin/perl

use strict;
use local::lib;
use Plack::Runner;

my $approot = 'gbvdoc';

my @argv = (
    '--workers'   => 5,
    '--port'      => 6100,
    '--pid'       => '/tmp/gbvdoc-starman.pid',
    '--error-log' => '/var/log/gbvdoc/starman.log',
    '/home/daia/code/gbvdoc/app.psgi'
);
    
my $runner = Plack::Runner->new(server => 'Starman', env => 'production');
$runner->parse_options(@argv);
$runner->set_options(argv => \@argv) if $runner->can('set_options');
$runner->run;

