package Debug::DBI::Default;

use strict;
use warnings;

use Log::Any::Adapter;
use DBI;
use Debug::DBI;

Log::Any::Adapter->set( { category => 'Debug::DBI' },
    'FileHandle',
    fh => exists $ENV{DDD_STDOUT} && $ENV{DDD_STDOUT} ? *STDOUT : *STDERR );

## no critic (ProhibitPackageVars)
our $obj = Debug::DBI->new(
    exists $ENV{DDD_SHOW_PASS}
        && $ENV{DDD_SHOW_PASS} ? ( hide_password => 0 ) : (),
    exists $ENV{DDD_MAX_ROWS} && $ENV{DDD_MAX_ROWS} =~ /\A\d+\z/xms
    ? ( max_rows => $ENV{DDD_MAX_ROWS} )
    : ()
)->install;
## use critic

1;

__END__

=pod

=head1 NAME

Debug::DBI::Default

=head1 SYNOPSIS

  In perl script:

    use Debug::DBI::Default;

  or from command line:

    perl -MDebug::DBI::Default <script name>

=head1 DESCRIPTION

=head1 SEE ALSO

L<Debug::DBI|Debug::DBI>, L<Log::Any::Adapter|Log::Any::Adapter>

