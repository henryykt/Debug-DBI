#!/usr/bin/env perl

use 5.008007;

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Debug::DBI',
    VERSION_FROM => 'lib/Debug/DBI.pm',
    AUTHOR       => 'Henry Tang <henryykt@gmail.com>',
    PREREQ_PM    => {
        'Mo'                            => '0.30',
        'Log::Any'                      => '0.14',
        'Log::Any::Adapter'             => '0.07',
        'Log::Any::Adapter::FileHandle' => '0.006',
    },
    LICENSE => 'artistic_2',
    test    => { TESTS => 't/*.t t/*/*.t t/*/*/*.t' }
);
