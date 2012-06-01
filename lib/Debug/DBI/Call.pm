package Debug::DBI::Call;

use strict;
use warnings;

use Mo qw(is required);

has arg_ref    => ( is => 'rw', required => 1 );
has callstack  => ( is => 'ro', required => 1 );
has formatter  => ( is => 'rw', required => 1 );
has method     => ( is => 'ro', required => 1 );
has log        => ( is => 'ro', required => 1 );
has log_prefix => ( is => 'rw', required => 1 );
has orig       => ( is => 'rw', required => 1 );
has result     => ( is => 'rw', required => 0 );
has wantarray  => ( is => 'ro', required => 0 );
has wrapper    => ( is => 'ro', required => 0 );

sub exec_orig {
    my $self = shift;
    return ref $self->wrapper eq 'CODE'
        ? $self->wrapper->($self)
        : $self->orig->( @{ $self->arg_ref } );
}

sub fix_err {
    my ( $self, $err, $prefix ) = @_;
    if ( $err =~ s/\sat.*?line\s\d+[.]\n$//xms ) {
        $err = sprintf qq{%s at %s line %d.\n}, $err,
            $self->callstack->[0]->{filename},
            $self->callstack->[0]->{line};
    }
    $self->print_warn( $prefix, q{ }, $err );
    return $err;
}

## no critic (RequireArgUnpacking)
sub print_info {
    my $self = shift;
    return $self->log->info( $self->log_prefix, q{ },
        $self->formatter->lines(@_) );
}
## use critic

## no critic (RequireArgUnpacking)
sub print_warn {
    my $self = shift;
    return $self->log->warn( $self->log_prefix, q{ },
        $self->formatter->lines(@_) );
}
## use critic

1;

__END__

=pod

=head1 NAME

Debug::DBI::Call - The data holder for the patched sub-routine calls

=head1 DESCRIPTION

Debug::DBI uses this module internally to hold data for each patched sub-routine call.

=head1 ATTRIBUTES

=head2 C<arg_ref>

Reference to original @_.

=head2 C<callstack>

Reference to array containg the caller information.

=head2 C<formatter>

Reference to L<Debug::DBI::Formatter|Debug::DBI::Formatter> object.

=head2 C<method>

Name of patch. See also L<Debug::DBI::patch_map|Debug::DBI::patch_map>.

=head2 C<log>

Reference to Log::Any logger.

=head2 C<log_prefix>

Prefix used in print_info() and print_warn().

=head2 C<orig>

Reference to original patched sub-routine.

=head2 C<result>

Reference to result value.

=head2 C<wantarray>

Indicates whether the patched sub-routine is called in array or scalar context.

=head2 C<wrapper>

Reference to optional method that is to be called instead
of the original method. See also L<exec_orig|exec_orig>.

=head1 METHODS

=head2 C<exec_orig>

If wrapper is present than it gets executed. If not than the original patched
sub-routine is executed.

=head2 C<fix_err>

=head2 C<print_info>

Prints info line to Log::Any logger.

=head2 C<print_warn>

Prints warning line to Log::Any Logger.

=head1 SEE ALSO

L<Debug::DBI|Debug::DBI>, L<Debug::DBI::Formatter|Debug::DBI::Formatter>

=cut
