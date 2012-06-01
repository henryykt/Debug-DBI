#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;

use lib join q{/}, File::Spec->splitdir( dirname __FILE__ ), q{..}, 'lib';

use Test::More qw(no_plan);

#use Test::More tests => 6;

use_ok('Debug::DBI::Formatter');

my @test_cases = (
    {   label      => 'with header row',
        header_row => [ 'a', 'b', 'c' ],
        body_rows  => [
            [ 'ab',  'def', 0 ],
            [ 'a',   'def', 'kl' ],
            [ 'abc', undef, 'kl2' ]
        ],
        footer_row => [],
        opt        => {},
        output     => q{*-----------*
|a  |b  |c  |
|---+---+---|
|ab |def|0  |
|a  |def|kl |
|abc|-N-|kl2|
*-----------*},
    },
    {   label      => 'with header and footer row',
        header_row => [ 'a', 'b', 'c' ],
        body_rows  => [
            [ 'ab',  'def', 0 ],
            [ 'a',   'def', 'kl' ],
            [ 'abc', undef, 'kl2' ]
        ],
        footer_row => [ 'f', 'kkk', '***' ],
        opt        => {},
        output     => q{*-----------*
|a  |b  |c  |
|---+---+---|
|ab |def|0  |
|a  |def|kl |
|abc|-N-|kl2|
|---+---+---|
|f  |kkk|***|
*-----------*},
    },
    {   label      => 'with different corners',
        header_row => [ 'a', 'b', 'c' ],
        body_rows  => [
            [ 'ab',  'def', 0 ],
            [ 'a',   'def', 'kl' ],
            [ 'abc', undef, 'kl2' ]
        ],
        footer_row => [],
        opt        => {
            lt_corner => '/',
            rt_corner => '\\',
            lb_corner => '\\',
            rb_corner => '/',
        },
        output => q{/-----------\
|a  |b  |c  |
|---+---+---|
|ab |def|0  |
|a  |def|kl |
|abc|-N-|kl2|
\-----------/},
    },
    {   label      => 'with different separators',
        header_row => [ 'a', 'b', 'c' ],
        body_rows  => [
            [ 'ab',  'def', 0 ],
            [ 'a',   'def', 'kl' ],
            [ 'abc', undef, 'kl2' ]
        ],
        footer_row => [],
        opt        => {
            lt_corner => '#',
            rt_corner => '#',
            lb_corner => '#',
            rb_corner => '#',
            v_sep     => '!',
            h_sep     => '=',
            c_sep     => '*',
        },
        output => q{#===========#
!a  !b  !c  !
!===*===*===!
!ab !def!0  !
!a  !def!kl !
!abc!-N-!kl2!
#===========#},
    },
    {   label      => 'with empty values',
        header_row => [ 'a', 'b', 'c' ],
        body_rows =>
            [ [ 'ab', 'def', 0 ], [ 'a', '', 'kl' ], [ 'abc', undef, '' ] ],
        footer_row => [],
        opt        => {},
        output     => q{*-----------*
|a  |b  |c  |
|---+---+---|
|ab |def|0  |
|a  |-E-|kl |
|abc|-N-|-E-|
*-----------*},
    },
    {   label      => 'long columns',
        header_row => [ 'a', 'b', 'c' ],
        body_rows  => [
            [ 'ab', 'def', 0 ],
            [ 'a',  '',    'kl' ],
            [   '123456789-123456789-123456789-123456789-123456789-123456789-123456789-123456789-123456789-123456789-',
                undef,
                ''
            ]
        ],
        footer_row => [],
        opt        => {},
        output =>
            q{*----------------------------------------------------------------------------------------*
|a                                                                               |b  |c  |
|--------------------------------------------------------------------------------+---+---|
|ab                                                                              |def|0  |
|a                                                                               |-E-|kl |
|123456789-123456789-123456789-123456789-123456789-123456789-123456789-123456[..]|-N-|-E-|
*----------------------------------------------------------------------------------------*},
    },
    {   label      => 'multilines',
        header_row => [ 'a', 'b', 'c' ],
        body_rows  => [
            [ 'ab', 'def', 0 ],
            [ 'a',  '',    'kl' ],
            [   qq{123456789-
123456789-
123456789-
123456789-}, undef, ''
            ]
        ],
        footer_row => [],
        opt        => {},
        output =>
            q{*------------------------------------------------------------*
|a                                                   |b  |c  |
|----------------------------------------------------+---+---|
|ab                                                  |def|0  |
|a                                                   |-E-|kl |
|123456789-[\n]123456789-[\n]123456789-[\n]123456789-|-N-|-E-|
*------------------------------------------------------------*},
    },
);

ok( my $f = Debug::DBI::Formatter->new, 'new' );

is( $f->c_sep,         '+',    'c_sep' );
is( $f->h_sep,         '-',    'h_sep' );
is( $f->v_sep,         '|',    'v_sep' );
is( $f->lt_corner,     '*',    'lt_corner' );
is( $f->rt_corner,     '*',    'rt_corner' );
is( $f->lb_corner,     '*',    'lb_corner' );
is( $f->rb_corner,     '*',    'rb_corner' );
is( $f->max_col_width, 80,     'max_col_width' );
is( $f->truncate_str,  '[..]', 'truncate_str' );

TESTCASE:
my $i = 0;
foreach my $tc (@test_cases) {
    $i++;
    $f = Debug::DBI::Formatter->new( exists $tc->{opt}
            && ref $tc->{opt} eq 'HASH' ? %{ $tc->{opt} } : () );
    is( $f->table(
            $tc->{header_row}, $tc->{body_rows},
            $tc->{footer_row}, $tc->{opt}
        ),
        $tc->{output},
        qq{table [$i] $tc->{label}}
    );
}

