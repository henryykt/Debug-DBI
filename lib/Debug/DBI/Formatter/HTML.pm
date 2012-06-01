package Debug::DBI::Formatter::HTML;

use strict;
use warnings;

use HTML::Entities;
use Mo;

extends 'Debug::DBI::Formatter';

## no critic (RequireArgUnpacking)
sub lines {
    my $self = shift;
    for (@_) { encode_entities($_) }
    return @_;
}
## use critic

1;

__END__

=pod

=head1 NAME

Debug::DBI::Formatter::HTML - HTML formatter

=head1 DESCRIPTION

=head1 SEE ALSO

L<Debug::DBI|Debug::DBI>, L<Debug::DBI::Formatter|Debug::DBI::Formatter>

=cut
