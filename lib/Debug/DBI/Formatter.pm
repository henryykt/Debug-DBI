package Debug::DBI::Formatter;

use strict;
use warnings;

use Mo qw{ default };

## no critic (ProhibitMagicNumbers ProhibitNoisyQuotes)
has 'c_sep'         => ( default => sub {'+'} );
has 'h_sep'         => ( default => sub {'-'} );
has 'v_sep'         => ( default => sub {'|'} );
has 'lt_corner'     => ( default => sub {'*'} );
has 'rt_corner'     => ( default => sub {'*'} );
has 'lb_corner'     => ( default => sub {'*'} );
has 'rb_corner'     => ( default => sub {'*'} );
has 'max_col_width' => ( default => sub {80} );
has 'truncate_str'  => ( default => sub {'[..]'} );
## use critic

## no critic (RequireArgUnpacking)
sub lines {
    my $self = shift;
    return @_;
}
## use critic

sub table {
    my ( $self, $header_row, $body_rows, $footer_row ) = @_;

    # Make sure these are defined
    for ( $body_rows, $header_row, $footer_row ) { $_ ||= []; }

    my $lt_corner    = $self->lt_corner;
    my $rt_corner    = $self->rt_corner;
    my $lb_corner    = $self->lb_corner;
    my $rb_corner    = $self->rb_corner;
    my $v_sep        = $self->v_sep;
    my $h_sep        = $self->h_sep;
    my $c_sep        = $self->c_sep;
    my $truncate_str = $self->truncate_str;
    my $max_colw     = $self->max_col_width;

    if ( $max_colw !~ /\A\d+\z/xms || $max_colw < 0 ) {
        $max_colw = 0;
    }

    # Find max width for each column
    # Also, cap on max column with and split into multi row lines
    #
    my $conv = sub {
        my $s = shift;
        if ( !defined $s ) {
            return q{};
        }
        $s =~ s/\n/\[\\n\]/gxms;
        $s =~ s/\r/\[\\r\]/gxms;

        if ( $max_colw > 0 && length $s > $max_colw ) {
            $s = substr( $s, 0, $max_colw - length $truncate_str )
                . $truncate_str;
        }

        return $s;
    };

    my @col_len = ();
ROW:
    foreach my $r ( $header_row, @{$body_rows}, $footer_row ) {
        my $cols = scalar @{$r};
    COL:
        foreach my $i ( 0 .. $cols - 1 ) {
            my $len = length $conv->( $r->[$i] );

            if ( !defined $col_len[$i] || $len > $col_len[$i] ) {
                $col_len[$i] = $len;
            }
        }
    }

    # Set min length
    ## no critic (ProhibitMagicNumbers)
COL:
    foreach my $len (@col_len) {
        if ( $len < 3 ) {
            $len = 3;
        }
    }
    ## use critic

    my $cols    = scalar @col_len;
    my $sep_row = sub {
        my ($sep) = @_;
        return join $sep, map { $h_sep x $col_len[$_] } ( 0 .. $cols - 1 );
    };
    my $body_row = sub {
        my ($r) = @_;
        $r = [ map { defined $_ ? $_ eq q{} ? '-E-' : $conv->($_) : '-N-' }
                @{$r} ];
        return join $v_sep,
            map { $r->[$_] . ( q{ } x ( $col_len[$_] - length $r->[$_] ) ) }
            ( 0 .. $cols - 1 );
    };

    # finally, build output table

    return join qq{\n}, $lt_corner . $sep_row->($h_sep) . $rt_corner,
        (
        scalar @{$header_row} > 0
        ? ( $v_sep . $body_row->($header_row) . $v_sep,
            $v_sep . $sep_row->($c_sep) . $v_sep
            )
        : ()
        ),
        ( map { $v_sep . $body_row->($_) . $v_sep } @{$body_rows} ),
        (
        scalar @{$footer_row} > 0
        ? ( $v_sep . $sep_row->($c_sep) . $v_sep,
            $v_sep . $body_row->($footer_row) . $v_sep
            )
        : ()
        ),
        $lb_corner . $sep_row->($h_sep) . $rb_corner;
}

1;

__END__

=pod

=head1 NAME

Debug::DBI::Formatter - Formatter

=head1 DESCRIPTION

=head1 SEE ALSO

L<Debug::DBI|Debug::DBI>

=cut
