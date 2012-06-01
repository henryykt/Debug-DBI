#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;

use lib join q{/}, File::Spec->splitdir( dirname __FILE__ ), q{..}, 'lib';

#use Test::More qw(no_plan);
use Test::More tests => 12;

use Debug::DBI;

ok( my $h = Debug::DBI->new, 'new' );

_test_is_delete($h);
_test_is_insert($h);
_test_is_select($h);
_test_is_update($h);

sub _test_is_delete {
    my ($h) = @_;

    is( $h->_is_delete(<<'END_OF_SQL'), 1, q{_is_delete 1} );
DELETE FROM...
END_OF_SQL
    is( $h->_is_delete(<<'END_OF_SQL'), 0, q{_is_delete 2 (insert)} );
INSERT INTO...
END_OF_SQL
    return;
}

sub _test_is_insert {
    my ($h) = @_;

    is( $h->_is_insert(<<'END_OF_SQL'), 1, q{_is_insert 1} );
INSERT INTO...
END_OF_SQL
    is( $h->_is_insert(<<'END_OF_SQL'), 0, q{_is_insert 2 (delete)} );
DELETER FROM...
END_OF_SQL
    return;
}

sub _test_is_select {
    my ($h) = @_;

    is( $h->_is_select(<<'END_OF_SQL'), 1, q{_is_select 1} );
SELECT ID
,      NAME
FROM   WSDB_PLAN
ORDER  BY ID
END_OF_SQL

    is( $h->_is_select(
            <<'END_OF_SQL'), 1, q{_is_select 2 (white space at beginning)} );
   SELECT ID
,      NAME
FROM   WSDB_PLAN
ORDER  BY ID
END_OF_SQL

    is( $h->_is_select(
            <<'END_OF_SQL'), 1, q{_is_select 3 (empty lines at beginning)} );

SELECT ID
,      NAME
FROM   WSDB_PLAN
ORDER  BY ID
END_OF_SQL

    is( $h->_is_select(<<'END_OF_SQL'), 0, q{_is_select 4 (insert)} );
INSERT INTO...
END_OF_SQL
    return;
}

sub _test_is_update {
    my ($h) = @_;

    is( $h->_is_update(<<'END_OF_SQL'), 1, q{_is_update 1} );
UPDATE ...
END_OF_SQL
    is( $h->_is_update(<<'END_OF_SQL'), 0, q{_is_update 2 (insert)} );
INSERT INTO...
END_OF_SQL
    is( $h->_is_update(<<'END_OF_SQL'), 0, q{_is_update 3 (delete)} );
DELETE FROM...
END_OF_SQL
    return;
}
