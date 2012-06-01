#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;

use lib join '/', File::Spec->splitdir( dirname __FILE__ ), '..', 'lib';
use lib join '/', File::Spec->splitdir( dirname __FILE__ ), 'lib';

use Test::More;

eval qq{use DBD::mysql};
plan skip_all => qq{DBD::mysql required for this test!} if $@;
plan skip_all => qq{set DDD_MYSQL to enable this test (developer only!)}
    if !( exists $ENV{DDD_MYSQL} && $ENV{DDD_MYSQL} );

plan tests => 19;

use Debug::DBI::Test qw{ capture_stderr };

# Check base module and its dependancies
use_ok('DBI');
use_ok('Log::Any');
use_ok('Log::Any::Adapter');
use_ok('Debug::DBI');
use_ok('Debug::DBI::Formatter');

my $log_category = 'MYSQL_Debug::DBI';

sub get_val {
    my ( $key, $name, $default ) = @_;

    if ( exists $ENV{$key} && defined $ENV{$key} && $ENV{$key} ne q{} ) {
        return $ENV{$key};
    }

    diag qq{Using default $name "$default". Set $key to change.};
    return $default;
}

################################################################
#
# IMPORTANT! BEWARE!
# This script is going to alter tables and data in the specified
# database!!!!
#
################################################################
my $db_host = get_val( 'DDD_HOST', 'db host', 'localhost' );
my $db_name = get_val( 'DDD_NAME', 'db name', 'ddd_db' );
my $db_user = get_val( 'DDD_USER', 'db user', 'ddd_user' );
my $db_pass = get_val( 'DDD_PASS', 'db pass', 'ddd_pass' );

Log::Any::Adapter->set( { category => $log_category }, 'FileHandle', );

ok( my $obj = Debug::DBI->new(
        log_category   => $log_category,
        show_callstack => 0,
        patches        => {
            default => 1,
            on_prepare => 0
        }
        )->install,
    q{new}
);

my $dbh;

is( capture_stderr(
        sub {
            $dbh
                = DBI->connect( qq{dbi:mysql:database=$db_name;host=$db_host},
                $db_user, $db_pass );

            #$dbh->{RaiseError} = 1;
        }
    ),
    qq{[info] [Debug::DBI::on_connect] Data source "dbi:mysql:database=$db_name;host=$db_host", user "$db_user", password "****"
[info] [Debug::DBI::on_connect] Connected.
},
    qq{on_connect}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
     DROP TABLE IF EXISTS ddd_user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $sth = $dbh->prepare($sql);
                $sth->execute;
            }
        }
    ),
    qq{[info] [Debug::DBI::on_execute] Statement:
     DROP TABLE IF EXISTS ddd_user

===Statement end===
},
    qq{on_execute drop table}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
CREATE TABLE ddd_user (id INT NOT NULL AUTO_INCREMENT, user_name TEXT, phone TEXT, PRIMARY KEY(id));
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $sth = $dbh->prepare($sql);
                $sth->execute;
            }
        }
    ),
    qq{[info] [Debug::DBI::on_execute] Statement:
CREATE TABLE ddd_user (id INT NOT NULL AUTO_INCREMENT, user_name TEXT, phone TEXT, PRIMARY KEY(id))
===Statement end===
},
    qq{on_execute create table}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
     INSERT INTO ddd_user (user_name, phone) VALUES ('Fred Bloggs','233-7777');
     INSERT INTO ddd_user (user_name, phone) VALUES ('Sanjay Patel','777-3333');
     INSERT INTO ddd_user (user_name, phone) VALUES ('Junk','xxx-xxxx');
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $sth = $dbh->prepare($sql);
                $sth->execute;
            }
        }
    ),
    qq{[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO ddd_user (user_name, phone) VALUES ('Fred Bloggs','233-7777')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id 1
[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO ddd_user (user_name, phone) VALUES ('Sanjay Patel','777-3333')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id 2
[info] [Debug::DBI::on_execute] Statement:
     INSERT INTO ddd_user (user_name, phone) VALUES ('Junk','xxx-xxxx')
===Statement end===
[info] [Debug::DBI::on_execute] Affected rows: 1, inserted id 3
},
    qq{on_execute inserts}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   ddd_user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $sth = $dbh->prepare($sql);
                $sth->execute;
            }
        }
    ),
    qq{[info] [Debug::DBI::on_execute] Statement:
SELECT *
FROM   ddd_user

===Statement end===
[info] [Debug::DBI::on_execute] Query returns 3 row(s). Result:
*-------------------------*
|id |user_name   |phone   |
|---+------------+--------|
|1  |Fred Bloggs |233-7777|
|2  |Sanjay Patel|777-3333|
|3  |Junk        |xxx-xxxx|
*-------------------------*
},
    qq{on_execute select}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   ddd_user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $row = $dbh->selectall_arrayref($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectall_arrayref] Statement:
SELECT *
FROM   ddd_user

===Statement end===
[info] [Debug::DBI::on_selectall_arrayref] Result:
*-------------------------*
|1  |Fred Bloggs |233-7777|
|2  |Sanjay Patel|777-3333|
|3  |Junk        |xxx-xxxx|
*-------------------------*
},
    qq{on_selectall_arrayref}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   ddd_user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $row = $dbh->selectall_hashref( $sql, 'id' );
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectall_hashref] Statement:
SELECT *
FROM   ddd_user

===Statement end===
[info] [Debug::DBI::on_selectall_hashref] Key field: "id"
[info] [Debug::DBI::on_selectall_hashref] Result:
*-------------------------*
|id |phone   |user_name   |
|---+--------+------------|
|1  |233-7777|Fred Bloggs |
|2  |777-3333|Sanjay Patel|
|3  |xxx-xxxx|Junk        |
*-------------------------*
},
    qq{on_selectall_hashref}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT user_name
FROM   ddd_user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $row = $dbh->selectcol_arrayref($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectcol_arrayref] Statement:
SELECT user_name
FROM   ddd_user

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
FROM   ddd_user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my @row = $dbh->selectrow_array($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectrow_array] Statement:
SELECT *
FROM   ddd_user

===Statement end===
[info] [Debug::DBI::on_selectrow_array] Result:
*------------------------*
|1  |Fred Bloggs|233-7777|
*------------------------*
},
    qq{on_selectrow_array}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   ddd_user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $row = $dbh->selectrow_arrayref($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectrow_arrayref] Statement:
SELECT *
FROM   ddd_user

===Statement end===
[info] [Debug::DBI::on_selectrow_arrayref] Result:
*------------------------*
|1  |Fred Bloggs|233-7777|
*------------------------*
},
    qq{on_selectrow_arrayref}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
SELECT *
FROM   ddd_user
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                my $row = $dbh->selectrow_hashref($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_selectrow_hashref] Statement:
SELECT *
FROM   ddd_user

===Statement end===
[info] [Debug::DBI::on_selectrow_hashref] Result:
*------------------------*
|id |phone   |user_name  |
|---+--------+-----------|
|1  |233-7777|Fred Bloggs|
*------------------------*
},
    qq{on_selectrow_hashref}
);

is( capture_stderr(
        sub {
            my $sqls = <<'END_OF_SQL';
     INSERT INTO ddd_user (user_name, phone) VALUES ('Food','123-xxxx');
     UPDATE ddd_user SET phone = '123-4567' WHERE user_name = 'Food';
END_OF_SQL
            foreach my $sql ( split /;\n+/, $sqls ) {
                $dbh->do($sql);
            }
        }
    ),
    qq{[info] [Debug::DBI::on_do] Statement:
     INSERT INTO ddd_user (user_name, phone) VALUES ('Food','123-xxxx')
===Statement end===
[info] [Debug::DBI::on_do] Affected rows: 1, inserted id 4
[info] [Debug::DBI::on_do] Statement:
     UPDATE ddd_user SET phone = '123-4567' WHERE user_name = 'Food'
===Statement end===
[info] [Debug::DBI::on_do] Updated rows: 1.
},
    qq{on_do insert, update}
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

