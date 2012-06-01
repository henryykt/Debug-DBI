#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;

use lib join '/', File::Spec->splitdir( dirname __FILE__ ), '..', 'lib';
use lib join '/', File::Spec->splitdir( dirname __FILE__ ), 'lib';

use Test::More;

use File::Temp qw{ tempdir tempfile };

use Debug::DBI::Test qw{ capture_stderr };

eval qq{use IO::String};
plan skip_all => qq{IO::String required for this test!} if $@;
plan tests => 9;

use_ok('DBI');
use_ok('Log::Any');
use_ok('Log::Any::Adapter');
use_ok('Debug::DBI');
use_ok('Debug::DBI::Formatter');

my $log_category = 'DBM_Debug::DBI';
my $log_buffer   = q{};
my $io           = IO::String->new($log_buffer);
Log::Any::Adapter->set( { category => $log_category },
    'FileHandle', fh => $io );

ok( my $obj = Debug::DBI->new(
        log_category   => $log_category,
        show_callstack => 0
        )->install,
    'new'
);

my $tempdir = tempdir( CLEANUP => 1 ) . '/';
my $dbh;

ok($dbh = DBI->connect(qq{dbi:DBM:f_dir=$tempdir}), 'connect');
ok($dbh->disconnect, 'disconnect');

is( $log_buffer,
    qq{[info] [Debug::DBI::on_connect] Data source "dbi:DBM:f_dir=$tempdir", user "-UNDEF-", password "****"
[info] [Debug::DBI::on_connect] Connected.
[info] [Debug::DBI::on_disconnect] Disconnected.
},
    'check log_buffer'
);


