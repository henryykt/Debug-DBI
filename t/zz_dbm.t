#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;

use lib join '/', File::Spec->splitdir( dirname __FILE__ ), '..', 'lib';
use lib join '/', File::Spec->splitdir( dirname __FILE__ ), 'lib';

#use Test::More qw(no_plan);
use Test::More tests => 32;

use File::Temp qw{ tempdir tempfile };

use Debug::DBI::Test qw{ capture_stderr };

# Check base module and its dependancies
use_ok('DBI');
use_ok('Log::Any');
use_ok('Log::Any::Adapter');
use_ok('Debug::DBI');
use_ok('Debug::DBI::Formatter');

my $log_category = 'DBM_Debug::DBI';

Log::Any::Adapter->set( { category => $log_category }, 'FileHandle' );

ok( my $obj = Debug::DBI->new(
        log_category   => $log_category,
        show_callstack => 0,
        )->install,
    'new'
);

is( $obj->constraint,    1,                       '->constraint' );
is( ref $obj->formatter, 'Debug::DBI::Formatter', '->formatter' );
is( $obj->hide_password, 1,                       '->hide_password' );
is( $obj->log_category,  $log_category,           '->log_category' );
is( $obj->max_rows,      500,                     '->max_rows' );
is_deeply(
    $obj->patch_map,
    {   on_begin_work => {
            package => 'DBI::db',
            method  => 'begin_work'
        },
        on_commit => {
            package => 'DBI::db',
            method  => 'commit'
        },
        on_connect => {
            package => 'DBI',
            method  => 'connect'
        },
        on_connect_cached => {
            package => 'DBI',
            method  => 'connect_cached'
        },
        on_disconnect => {
            package => 'DBI::db',
            method  => 'disconnect'
        },
        on_do => {
            package => 'DBI::db',
            method  => 'do'
        },
        on_execute => {
            package => 'DBI::st',
            method  => 'execute'
        },
        on_prepare => {
            package => 'DBI::db',
            method  => 'prepare'
        },
        on_prepare_cached => {
            package => 'DBI::db',
            method  => 'prepare_cached'
        },
        on_rollback => {
            package => 'DBI::db',
            method  => 'rollback'
        },
        on_selectall_arrayref => {
            package => 'DBI::db',
            method  => 'selectall_arrayref'
        },
        on_selectall_hashref => {
            package => 'DBI::db',
            method  => 'selectall_hashref'
        },
        on_selectcol_arrayref => {
            package => 'DBI::db',
            method  => 'selectcol_arrayref'
        },
        on_selectrow_array => {
            package => 'DBI::db',
            method  => 'selectrow_array'
        },
        on_selectrow_arrayref => {
            package => 'DBI::db',
            method  => 'selectrow_arrayref'
        },
        on_selectrow_hashref => {
            package => 'DBI::db',
            method  => 'selectrow_hashref'
        },
    },
    '->patch_map'
);
is_deeply( $obj->patches, { default => 1, }, '->patches' );
is( $obj->show_callstack, 0,     '->show_callstack' );
is( $obj->wrap_orig,      undef, '->wrap_orig' );

my $tempdir = tempdir( CLEANUP => 1 ) . '/';

#diag(qq{TEMPDIR[$tempdir]});

my $dbh;
my $dbh2;

is( capture_stderr(
        sub {
            $dbh = DBI->connect(qq{dbi:DBM:f_dir=$tempdir});
            $dbh->{RaiseError} = 1;
        }
    ),
    qq{[info] [Debug::DBI::on_connect] Data source "dbi:DBM:f_dir=$tempdir", user "-UNDEF-", password "****"
[info] [Debug::DBI::on_connect] Connected.
},
    qq{on_connect}
);

is( capture_stderr(
        sub {
            $dbh2 = DBI->connect_cached(qq{dbi:DBM:f_dir=$tempdir});
            $dbh2->{RaiseError} = 1;
        }
    ),
    qq{[info] [Debug::DBI::on_connect_cached] Data source "dbi:DBM:f_dir=$tempdir", user "-UNDEF-", password "****"
[info] [Debug::DBI::on_connect_cached] Connected.
},
    qq{on_connect_cached}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
     CREATE TABLE user ( user_name TEXT, phone TEXT );
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $sth = $dbh->prepare($sql);
                $sth->execute;
            }
        }
    ),
    qq{[info] [Debug::DBI::on_prepare] Statement:
     CREATE TABLE user ( user_name TEXT, phone TEXT )
===Statement end===
[info] [Debug::DBI::on_execute] Statement:
     CREATE TABLE user ( user_name TEXT, phone TEXT )
===Statement end===
},
    qq{on_execute create table}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
     INSERT INTO user VALUES ('Fred Bloggs','233-7777');
     INSERT INTO user VALUES ('Sanjay Patel','777-3333');
     INSERT INTO user VALUES ('Junk','xxx-xxxx');
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $sth = $dbh->prepare_cached($sql);
                $sth->execute;
            }
        }
    ),
    qq{[info] [Debug::DBI::on_prepare_cached] Statement:
     INSERT INTO user VALUES ('Fred Bloggs','233-7777')
===Statement end===
[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO user VALUES ('Fred Bloggs','233-7777')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id -UNKNOWN-
[info] [Debug::DBI::on_prepare_cached] Statement:
     INSERT INTO user VALUES ('Sanjay Patel','777-3333')
===Statement end===
[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO user VALUES ('Sanjay Patel','777-3333')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id -UNKNOWN-
[info] [Debug::DBI::on_prepare_cached] Statement:
     INSERT INTO user VALUES ('Junk','xxx-xxxx')
===Statement end===
[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO user VALUES ('Junk','xxx-xxxx')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id -UNKNOWN-
},
    qq{on_execute inserts}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $sth = $dbh->prepare($sql);
                $sth->execute;
            }
        }
    ),
    qq{[info] [Debug::DBI::on_prepare] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_execute] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_execute] Query returns 3 row(s). Result:
*---------------------*
|user_name   |phone   |
|------------+--------|
|Fred Bloggs |233-7777|
|Sanjay Patel|777-3333|
|Junk        |xxx-xxxx|
*---------------------*
},
    qq{on_execute select}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $row = $dbh->selectall_arrayref($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectall_arrayref] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_selectall_arrayref] Result:
*---------------------*
|Fred Bloggs |233-7777|
|Sanjay Patel|777-3333|
|Junk        |xxx-xxxx|
*---------------------*
},
    qq{on_selectall_arrayref}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $sth = $dbh->prepare($sql);
                my $row = $dbh->selectall_arrayref($sth);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_prepare] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_selectall_arrayref] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_selectall_arrayref] Result:
*---------------------*
|Fred Bloggs |233-7777|
|Sanjay Patel|777-3333|
|Junk        |xxx-xxxx|
*---------------------*
},
    qq{on_selectall_arrayref with prepared statement}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $row = $dbh->selectall_hashref( $sql, 'user_name' );
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectall_hashref] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_selectall_hashref] Key field: "user_name"
[info] [Debug::DBI::on_selectall_hashref] Result:
*---------------------*
|phone   |user_name   |
|--------+------------|
|233-7777|Fred Bloggs |
|xxx-xxxx|Junk        |
|777-3333|Sanjay Patel|
*---------------------*
},
    qq{on_selectall_hashref}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $sth = $dbh->prepare($sql);
                my $row = $dbh->selectall_hashref( $sth, 'user_name' );
            }
        }
    ),
    qq{[info] [Debug::DBI::on_prepare] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_selectall_hashref] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_selectall_hashref] Key field: "user_name"
[info] [Debug::DBI::on_selectall_hashref] Result:
*---------------------*
|phone   |user_name   |
|--------+------------|
|233-7777|Fred Bloggs |
|xxx-xxxx|Junk        |
|777-3333|Sanjay Patel|
*---------------------*
},
    qq{on_selectall_hashref with prepared statement}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $row = $dbh->selectcol_arrayref($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectcol_arrayref] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_selectcol_arrayref] Result:
*-----------------------------*
|Fred Bloggs|Sanjay Patel|Junk|
*-----------------------------*
},
    qq{on_selectcol_arrayref}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my @row = $dbh->selectrow_array($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectrow_array] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_selectrow_array] Result:
*--------------------*
|Fred Bloggs|233-7777|
*--------------------*
},
    qq{on_selectrow_array}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $row = $dbh->selectrow_arrayref($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectrow_arrayref] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_selectrow_arrayref] Result:
*--------------------*
|Fred Bloggs|233-7777|
*--------------------*
},
    qq{on_selectrow_arrayref}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $row = $dbh->selectrow_hashref($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectrow_hashref] Statement:
SELECT *
FROM   user

===Statement end===
[info] [Debug::DBI::on_selectrow_hashref] Result:
*--------------------*
|phone   |user_name  |
|--------+-----------|
|233-7777|Fred Bloggs|
*--------------------*
},
    qq{on_selectrow_hashref}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
     INSERT INTO user VALUES ('Food','123-xxxx');
     UPDATE user SET phone = '123-4567' WHERE user_name = 'Food';
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                $dbh->do($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_do] Statement:
     INSERT INTO user VALUES ('Food','123-xxxx')
===Statement end===
[info] [Debug::DBI::on_do] Affected rows: 1, inserted id -UNKNOWN-
[info] [Debug::DBI::on_do] Statement:
     UPDATE user SET phone = '123-4567' WHERE user_name = 'Food'
===Statement end===
[info] [Debug::DBI::on_do] Updated rows: 1.
},
    qq{on_do insert, update}
);

like(
    capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
     INSERT INTO unknown_table VALUES ('Food','123-xxxx');
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                $dbh->do($sql);
            }
        }
    ),
    qr{^\[info\] \[Debug::DBI::on_do\] Statement:
     INSERT INTO unknown_table VALUES \('Food','123-xxxx'\)
===Statement end===
\[warning\] \[Debug::DBI::on_do\] DIE: Cannot open.*
}s,
    qq{exception}
);

is( capture_stderr(
        sub {
            $dbh->disconnect;
        }
    ),
    qq{[info] [Debug::DBI::on_disconnect] Disconnected.
},
    qq{on_disconnect}
);

is( capture_stderr(
        sub {
            $dbh2->disconnect;
        }
    ),
    qq{[info] [Debug::DBI::on_disconnect] Disconnected.
},
    qq{on_disconnect 2}
);

