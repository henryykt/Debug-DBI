#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;

use lib join q{/}, File::Spec->splitdir( dirname __FILE__ ), q{..}, 'lib';
use lib join q{/}, File::Spec->splitdir( dirname __FILE__ ), 'lib';

#use Test::More qw(no_plan);
use Test::More tests => 3;

use File::Temp qw{ tempdir tempfile };

use Debug::DBI::Test qw{ capture_stderr };

use_ok('Debug::DBI::Default');

my $tempdir = tempdir( CLEANUP => 1 ) . q{/};
my $dbh;

like(
    capture_stderr(
        sub {
            $dbh = DBI->connect(qq{dbi:DBM:f_dir=$tempdir});
            $dbh->{RaiseError} = 1;
        }
    ),
    qr{^\[info\] \[Debug::DBI::on_connect\] Caller:.*
 \[0\].*
\[info\] \[Debug::DBI::on_connect\] Data source "dbi:DBM:f_dir=.*?", user "-UNDEF-", password "\*\*\*\*"
\[info\] \[Debug::DBI::on_connect\] Connected\.
$}s,
    q{on_connect}
);

like(
    capture_stderr(
        sub {
            $dbh->disconnect;
        }
    ),
    qr{^\[info\] \[Debug::DBI::on_disconnect\] Caller:.*\[info\] \[Debug::DBI::on_disconnect\] Disconnected\.
}s,
    q{on_disconnect}
);

