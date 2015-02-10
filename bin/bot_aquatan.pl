#!/usr/bin/perl

# 量産型Aquatan型bot「aquatan_lite」

use strict;
use warnings;
use utf8;

use lib qw(../lib);

use Aquatan::Event;

my $aquatan = Aquatan::Event->new(config_name => 'aqua');
$aquatan->eventloop;

1;

