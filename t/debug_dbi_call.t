#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;

use lib join q{/}, File::Spec->splitdir( dirname __FILE__ ), q{..}, 'lib';

use Test::More qw(no_plan);

#use Test::More tests => 12;

use_ok('Debug::DBI::Call');
can_ok(
    'Debug::DBI::Call', 'arg_ref',   'callstack',  'formatter',
    'method',           'log',       'log_prefix', 'orig',
    'result',           'wantarray', 'wrapper'
);
