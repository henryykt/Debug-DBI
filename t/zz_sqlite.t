#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;

use lib join '/', File::Spec->splitdir( dirname __FILE__ ), '..', 'lib';
use lib join '/', File::Spec->splitdir( dirname __FILE__ ), 'lib';

use Test::More;

eval qq{use DBD::SQLite};
plan skip_all => qq{DBD::SQLite required for this test!} if $@;
plan tests => 23;

use File::Temp qw{ tempdir tempfile };

use Debug::DBI::Test qw{ capture_stderr };

# Check base module and its dependancies
use_ok('DBI');
use_ok('Log::Any');
use_ok('Log::Any::Adapter');
use_ok('Debug::DBI');
use_ok('Debug::DBI::Formatter');

my $log_category = 'SQLITE_Debug::DBI';

Log::Any::Adapter->set( { category => $log_category }, 'FileHandle' );

ok( my $obj = Debug::DBI->new(
        log_category   => $log_category,
        show_callstack => 0,
        patches        => {
            on_prepare => 0,
            default    => 1,
        }
        )->install,
    q{new}
);

my $tempdir = tempdir( CLEANUP => 1 ) . '/';

#diag(qq{TEMPDIR[$tempdir]});

my $dbh;

is( capture_stderr(
        sub {
            $dbh
                = DBI->connect(qq{dbi:SQLite:dbname=${tempdir}testdb.sqlite});
            $dbh->{RaiseError} = 1;
            $dbh->{AutoCommit} = 0;
        }
    ),
    qq{[info] [Debug::DBI::on_connect] Data source "dbi:SQLite:dbname=${tempdir}testdb.sqlite", user "-UNDEF-", password "****"
[info] [Debug::DBI::on_connect] Connected.
},
    qq{on_connect}
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
    qq{[info] [Debug::DBI::on_execute] Statement:
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
                my $sth = $dbh->prepare($sql);
                $sth->execute;
            }
        }
    ),
    qq{[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO user VALUES ('Fred Bloggs','233-7777')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id 1
[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO user VALUES ('Sanjay Patel','777-3333')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id 2
[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO user VALUES ('Junk','xxx-xxxx')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id 3
},
    qq{on_execute inserts}
);

is( capture_stderr(
        sub {
            $dbh->commit;
        }
    ),
    qq{[info] [Debug::DBI::on_commit] rc = 1.
},
    qq{on_commit}
);

is( capture_stderr(
        sub {
            $dbh->{AutoCommit} = 1;
            $dbh->begin_work;
        }
    ),
    qq{[info] [Debug::DBI::on_begin_work] rc = 1.
},
    qq{on_begin_work}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
     INSERT INTO user VALUES ('Fred Bloggs','233-7777');
     INSERT INTO user VALUES ('Sanjay Patel','777-3333');
     INSERT INTO user VALUES ('Junk','xxx-xxxx');
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $sth = $dbh->prepare($sql);
                $sth->execute;
            }
        }
    ),
    qq{[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO user VALUES ('Fred Bloggs','233-7777')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id 4
[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO user VALUES ('Sanjay Patel','777-3333')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id 5
[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO user VALUES ('Junk','xxx-xxxx')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id 6
},
    qq{on_execute inserts before rollback}
);

is( capture_stderr(
        sub {
            $dbh->rollback;
        }
    ),
    qq{[info] [Debug::DBI::on_rollback] rc = 1.
},
    qq{on_rollback}
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
    qq{[info] [Debug::DBI::on_execute] Statement:
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
[info] [Debug::DBI::on_do] Affected rows: 1, inserted id 4
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
\[warning\] \[Debug::DBI::on_do\] WARN: DBD::SQLite::db do failed.*
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

