package Debug::DBI::Test;

use strict;
use warnings;
use Carp;

use base qw(Exporter);
our @EXPORT_OK = qw(capture_stderr);

use File::Temp qw{ tempfile };
use English '-no_match_vars';

# Redirect STDERR to temporary file. Execute function and return
# captured output.
sub capture_stderr {
    my ($func_to_exec) = @_;

    my ( $temp_file_handle_stderr, $temp_file_name_stderr )
        = tempfile( UNLINK => 1, EXLOCK => 0 );

    ## no critic (RequireBriefOpen)
    open my $old_file_handle_stderr, '>&STDERR'
        or croak qq{Can't dup STDERR: $ERRNO};
    ## use critic

    open STDERR, '>', $temp_file_name_stderr
        or croak qq{Can't redirect STDERR to $temp_file_name_stderr: $ERRNO};

    my $store = $OUTPUT_AUTOFLUSH;

    ## no critic (ProhibitOneArgSelect)
    select STDERR;
    ## use critic
    $OUTPUT_AUTOFLUSH = 1;

    eval { $func_to_exec->(); 1 } or do { };

    open STDERR, '>&', $old_file_handle_stderr
        or croak qq{Can't dup old_stderr: $ERRNO};

    $OUTPUT_AUTOFLUSH = $store;

    open my $fh, '<', $temp_file_name_stderr
        or confess qq{$temp_file_name_stderr: $ERRNO};

    # Slurp temp. file content.
    my $stderr_output = do {
        local $INPUT_RECORD_SEPARATOR = undef;
        <$fh>;
    };
    my $rc = close $fh;

    return $stderr_output;
}

1;
