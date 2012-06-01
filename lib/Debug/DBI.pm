package Debug::DBI;

use strict;
use warnings;
use Carp;

our $VERSION = '0.01';

use Log::Any;

use Debug::DBI::Call;
use Debug::DBI::Formatter;

use Mo qw( is default build );

## no critic (ProhibitMagicNumbers)
has 'constraint'     => ( default => sub {1} );
has 'formatter'      => ( default => sub { Debug::DBI::Formatter->new } );
has 'hide_password'  => ( default => sub {1} );
has 'log_category'   => ( default => sub {__PACKAGE__} );
has 'max_rows'       => ( default => sub {500} );
has 'show_callstack' => ( default => sub {1} );
has 'wrap_orig'      => ( default => sub {undef} );
has 'patch_map'      => (
    is      => 'ro',
    default => sub {
        {   on_begin_work => {
                package => 'DBI::db',
                method  => 'begin_work'
            },
            on_commit => {
                package => 'DBI::db',
                method  => 'commit'
            },
            on_connect => {
                package => 'DBI',
                method  => 'connect'
            },
            on_connect_cached => {
                package => 'DBI',
                method  => 'connect_cached'
            },
            on_disconnect => {
                package => 'DBI::db',
                method  => 'disconnect'
            },
            on_do => {
                package => 'DBI::db',
                method  => 'do'
            },
            on_execute => {
                package => 'DBI::st',
                method  => 'execute'
            },
            on_prepare => {
                package => 'DBI::db',
                method  => 'prepare'
            },
            on_prepare_cached => {
                package => 'DBI::db',
                method  => 'prepare_cached'
            },
            on_rollback => {
                package => 'DBI::db',
                method  => 'rollback'
            },
            on_selectall_arrayref => {
                package => 'DBI::db',
                method  => 'selectall_arrayref'
            },
            on_selectall_hashref => {
                package => 'DBI::db',
                method  => 'selectall_hashref'
            },
            on_selectcol_arrayref => {
                package => 'DBI::db',
                method  => 'selectcol_arrayref'
            },
            on_selectrow_array => {
                package => 'DBI::db',
                method  => 'selectrow_array'
            },
            on_selectrow_arrayref => {
                package => 'DBI::db',
                method  => 'selectrow_arrayref'
            },
            on_selectrow_hashref => {
                package => 'DBI::db',
                method  => 'selectrow_hashref'
            }
        };
    }
);
## use critic

has 'patches' => (    # define which patches are enabled
    is      => 'ro',
    default => sub { { default => 1 } }
);

## no critic (ProhibitPackageVars)
our $g_is_in_handler = 0;    # prevent recursing into handler
## use critic

sub BUILD {
    my $self = shift;

    $self->{_patches} = {};
    return;
}

sub install {
    my $self = shift;

    my $patches = $self->patches;
METHOD:
    while ( my ( $method, $c ) = each %{ $self->patch_map } ) {
        if (!$self->can($method)
            || !(
                  exists $patches->{$method} ? $patches->{$method}
                : exists $patches->{default} ? $patches->{default}
                : 0
            )
            )
        {
            next METHOD;
        }

        my $name = $c->{package} . '::' . $c->{method};
        if ( exists $self->{_patches}->{$name} ) {
            croak qq{$name already patched!};
        }
        my $orig;
        my $handler = sub {

            # Prevent recursion
            if ($g_is_in_handler) {
                goto $orig;
            }

            ## no critic (ProhibitLocalVars)
            local $g_is_in_handler = 1;
            ## use critic

            my $constraint
                = $self->_select_handler( $self->constraint, $method,
                'default', 1 );
            my $wrapper = $self->_select_handler( $self->wrap_orig, $method,
                'default', undef );
            my $call = Debug::DBI::Call->new(
                callstack => $self->_callstack('Debug::DBI::__ANON__'),
                formatter => $self->formatter,
                method    => $method,
                log =>
                    Log::Any->get_logger( category => $self->log_category ),
                log_prefix => sprintf( '[%s::%s]', __PACKAGE__, $method ),
                orig       => $orig,
                arg_ref    => \@_,
                wrapper    => $wrapper,
                wantarray => wantarray ? 1 : 0,
            );

            if ( !$constraint
                || ( ref $constraint eq 'CODE' && !$constraint->($call) ) )
            {
                return $call->exec_orig;
            }

            if ( $self->show_callstack ) {
                $self->show_caller($call);
            }

            # Make sure that die and warn print the original script line and
            # input line number.
            ## no critic (RequireCarping)
            local $SIG{__WARN__} = sub {
                warn $call->fix_err( shift, 'WARN:' );
            };

            local $SIG{__DIE__} = sub {
                die $call->fix_err( shift, 'DIE:' );
            };
            ## use critic

            $self->$method($call);
        };

        ## no critic (ProhibitNoWarnings ProhibitNoStrict)
        no warnings 'redefine';
        no strict 'refs';
        ## use critic

        $orig = *{$name}{CODE};
        *{$name} = $handler;
        $self->{_patches}->{$name} = { orig => $orig };
    }
    return $self;
}

sub on_begin_work {
    my ( $self, $call ) = @_;
    my $rc = $call->exec_orig;
    $call->print_info( 'rc = ', defined $rc ? $rc : '-UNDEF-', q{.} );
    return $rc;
}

sub on_commit {
    my ( $self, $call ) = @_;
    my $rc = $call->exec_orig;
    $call->print_info( 'rc = ', defined $rc ? $rc : '-UNDEF-', q{.} );
    return $rc;
}

sub on_connect {
    my ( $self, $call ) = @_;
    my ( $class, $data_source, $user, $word, $attr ) = @{ $call->arg_ref };

    $call->print_info(
        sprintf q{Data source "%s", user "%s", password "%s"},
        $data_source,
        defined $user ? $user : '-UNDEF-',
        $self->hide_password ? '****' : defined $word ? $word : '-UNDEF-'
    );

    my $dbh = $call->exec_orig;
    if ( !defined $dbh ) {
        $call->print_warn(
            sprintf q{Could not connect to "%s", user "%s" (db undefined)},
            $data_source, defined $user ? $user : '-UNDEF-' );
    }
    elsif ( $dbh->err ) {
        $call->print_warn( 'Database error: ', $dbh->err );
    }
    else {
        $call->print_info('Connected.');
    }

    return $dbh;
}

sub on_connect_cached {
    goto &on_connect;
}

sub on_disconnect {
    my ( $self, $call ) = @_;

    my $rc = $call->exec_orig;
    if ( !defined $rc ) {
        $call->print_warn( 'Error: ', $call->arg_ref->[0]->errstr );
    }
    else {
        $call->print_info('Disconnected.');
    }

    return $rc;
}

sub on_do {
    my ( $self, $call ) = @_;
    my ( $dbh, $sql, $attr, @arg ) = @{ $call->arg_ref };

    $self->show_sql( $call, $sql, \@arg );

    my $rv = $call->exec_orig;
    if ( !defined $rv ) {
        $call->print_warn( 'Execute not successful: ', $dbh->errstr );

        return $rv;
    }

    # We don't expect SELECT here
    if ( $self->_is_insert($sql) ) {
        $self->show_insert( $call, $dbh, \@arg, $rv );
    }
    elsif ( $self->_is_update($sql) ) {
        $self->show_update( $call, $dbh, \@arg, $rv );
    }
    elsif ( $self->_is_delete($sql) ) {
        $self->show_delete( $call, $dbh, \@arg, $rv );
    }
    else {
        $self->show_sql_rv( $call, $dbh, \@arg, $rv );
    }
    return $rv;
}

sub on_execute {
    my ( $self, $call ) = @_;
    my ( $sth,  @arg )  = @{ $call->arg_ref };
    my $sql = $sth->{Statement};

    $self->show_sql( $call, $sql, \@arg );

    my $rv = $call->exec_orig;
    if ( !defined $rv ) {
        $call->print_warn( 'Execute not successful: ',
            $sth->{Database}->errstr );

        return $rv;
    }
    ## no critic (ProhibitCascadingIfElse)
    if ( $self->_is_select($sql) ) {
        $self->show_select( $call, $sth, \@arg );
    }
    elsif ( $self->_is_insert($sql) ) {
        $self->show_insert( $call, $sth, \@arg, $rv );
    }
    elsif ( $self->_is_update($sql) ) {
        $self->show_update( $call, $sth, \@arg, $rv );
    }
    elsif ( $self->_is_delete($sql) ) {
        $self->show_delete( $call, $sth, \@arg, $rv );
    }
    ## use critic
    return $rv;
}

sub on_prepare {
    my ( $self, $call ) = @_;
    my ( $dbh, $sql, $attr ) = @{ $call->arg_ref };

    $self->show_sql( $call, $sql );

    my $sth = $call->exec_orig;
    if ( !defined $sth ) {
        $call->print_warn( 'Prepare not successful: ', $dbh->errstr );

    }
    return $sth;
}

sub on_prepare_cached {
    goto &on_prepare;
}

sub on_rollback {
    my ( $self, $call ) = @_;
    my $rc = $call->exec_orig;
    $call->print_info( 'rc = ', defined $rc ? $rc : '-UNDEF-', q{.} );
    return $rc;
}

sub on_selectall_arrayref {
    my ( $self, $call ) = @_;
    my ( $dbh, $obj, $attr, @arg ) = @{ $call->arg_ref };

    my $sql = ref $obj eq 'DBI::st' ? $obj->{Statement} : $obj;

    $self->show_sql( $call, $sql, \@arg );

    my $ary_ref = $call->exec_orig;

    $call->print_info( qq{Result:\n},
        $self->formatter->table( undef, $ary_ref ) );
    return $ary_ref;
}

sub on_selectall_hashref {
    my ( $self, $call ) = @_;
    my ( $dbh, $obj, $key_field, $attr, @arg ) = @{ $call->arg_ref };

    my $sql = ref $obj eq 'DBI::st' ? $obj->{Statement} : $obj;

    $self->show_sql( $call, $sql, \@arg );
    $call->print_info(qq{Key field: "$key_field"});

    my $hash_ref = $call->exec_orig;

    # Format output as a table
    if ( ref $hash_ref eq 'HASH' ) {
        my @h         = ();
        my @body_rows = ();

        my $row_idx = 0;
        foreach my $pk ( sort { $a cmp $b } keys %{$hash_ref} ) {
            my $row_ref = $hash_ref->{$pk};

            my @b = ();
            foreach my $k ( sort { $a cmp $b } keys %{$row_ref} ) {
                if ( $row_idx == 0 ) {
                    push @h, $k;
                }
                push @b, $row_ref->{$k};
            }
            push @body_rows, \@b;
            $row_idx++;
        }
        $call->print_info( qq{Result:\n},
            $self->formatter->table( \@h, \@body_rows ) );
    }
    return $hash_ref;
}

sub on_selectcol_arrayref {
    my ( $self, $call ) = @_;
    my ( $dbh, $obj, $attr, @arg ) = @{ $call->arg_ref };

    my $sql = ref $obj eq 'DBI::st' ? $obj->{Statement} : $obj;

    $self->show_sql( $call, $sql, \@arg );

    my $ary_ref = $call->exec_orig;

    $call->print_info( qq{Result:\n},
        $self->formatter->table( undef, [$ary_ref] ) );
    return $ary_ref;
}

sub on_selectrow_array {
    my ( $self, $call ) = @_;
    my ( $dbh, $obj, $attr, @arg ) = @{ $call->arg_ref };

    my $sql = ref $obj eq 'DBI::st' ? $obj->{Statement} : $obj;

    $self->show_sql( $call, $sql, \@arg );

    my @rv = $call->exec_orig;
    $call->print_info( qq{Result:\n},
        $self->formatter->table( undef, [ \@rv ] ) );

    return @rv;
}

sub on_selectrow_arrayref {
    my ( $self, $call ) = @_;
    my ( $dbh, $obj, $attr, @arg ) = @{ $call->arg_ref };

    my $sql = ref $obj eq 'DBI::st' ? $obj->{Statement} : $obj;

    $self->show_sql( $call, $sql, \@arg );

    my $ary_ref = $call->exec_orig;

    if ( !defined $ary_ref ) {
        $call->print_warn( 'Error: ', $dbh->errstr );
    }
    else {
        $call->print_info( qq{Result:\n},
            $self->formatter->table( undef, [$ary_ref] ) );
    }
    return $ary_ref;
}

sub on_selectrow_hashref {
    my ( $self, $call ) = @_;
    my ( $dbh, $obj, $attr, @arg ) = @{ $call->arg_ref };

    my $sql = ref $obj eq 'DBI::st' ? $obj->{Statement} : $obj;

    $self->show_sql( $call, $sql, \@arg );

    my $hash_ref = $call->exec_orig;

    # Format output as a table
    if ( ref $hash_ref eq 'HASH' ) {
        my @h = ();
        my @b = ();

        foreach my $k ( sort { $a cmp $b } keys %{$hash_ref} ) {
            push @h, $k;
            push @b, $hash_ref->{$k};
        }
        $call->print_info( qq{Result:\n},
            $self->formatter->table( \@h, [ \@b ] ) );
    }
    return $hash_ref;
}

sub show_caller {
    my ( $self, $call ) = @_;

    my $callstack = $call->callstack;
    my $out       = 'Caller:';

    if ( scalar @{$callstack} == 0 ) {
        $out .= ' -UNKNOWN-';
    }
    else {
    CALLER:
        foreach my $i ( 0 .. scalar @{$callstack} - 1 ) {
            $out .= sprintf qq{\n [%d] %s from %s:%s},
                $i, @{ $callstack->[$i] }{ 'subroutine', 'filename', 'line' };
        }
    }
    $call->print_info($out);

    return $self;
}

sub show_delete {
    my ( $self, $call, $obj, $arg, $rv ) = @_;

    $call->print_info( 'Deleted rows: ',
        defined $rv ? $rv : '-UNKNOWN-', q{.} );

    return $self;
}

sub show_insert {
    my ( $self, $call, $obj, $arg, $rv ) = @_;

    # $obj can be eigher database handle or statement
    my $dbh = ref $obj eq 'DBI::st' ? $obj->{Database} : $obj;
    my $driver = $dbh->{Driver}->{Name};
    my $last_id;
    if ( lc $driver eq 'mysql' ) {
        $last_id = $dbh->{mysql_insertid};
    }
    elsif ( lc $driver eq 'sqlite' ) {
        $last_id = $dbh->sqlite_last_insert_rowid;
    }

    $call->print_info(
        'Affected rows: ',
        defined $rv ? $rv : '-UNKNOWN-',
        ', inserted id ',
        defined $last_id ? $last_id : '-UNKNOWN-'
    );

    return $self;
}

sub show_select {
    my ( $self, $call, $sth, $arg ) = @_;

    my $dbh          = $sth->{Database};
    my $driver       = lc $dbh->{Driver}->{Name};
    my $max_rows     = $self->max_rows;
    my $rows_unknown = $driver eq 'sqlite' ? 1 : 0;
    my $rows         = $sth->rows;
    my $row_msg
        = $rows_unknown
        ? qq{Cannot determine number of rows for $driver.}
        : qq{Query returns $rows row(s).};

    if ( defined $max_rows && $max_rows < 1 ) {
        $call->print_info( $row_msg,
            ' Results are not displayed due to max_rows limit (0).' );
        return $self;
    }

    my $dsth = $dbh->prepare( $sth->{Statement} );

    $call->orig->( $dsth, ref $arg eq 'ARRAY' ? @{$arg} : () );

    my $fetched_rows_ref = $dsth->fetchall_arrayref( undef, $max_rows );
    my $fetched_rows = scalar @{$fetched_rows_ref};

    if ($rows_unknown) {
        if ( $fetched_rows < $max_rows ) {
            $rows    = $fetched_rows;
            $row_msg = qq{Query returns $rows row(s).};
        }
        else {
            $row_msg .= qq{ Only displaying first $max_rows rows.};
        }
    }
    elsif ( $rows > $max_rows ) {
        $row_msg .= qq{ Only displaying first $max_rows rows.};
    }

    $call->print_info( $row_msg, qq{ Result:\n},
        $self->formatter->table( $sth->{NAME}, $fetched_rows_ref ) );

    $dsth->finish;

    return $self;
}

sub show_sql {
    my ( $self, $call, $sql, $arg ) = @_;

    my $out = qq{Statement:\n} . $sql;

    if ( defined $arg && ref $arg eq 'ARRAY' && scalar @{$arg} > 0 ) {
        $out .= qq{\n===Argument(s):===};
        for ( 0 .. scalar @{$arg} - 1 ) {
            $out .= sprintf qq{\n%i: "%s"}, $_, $arg->[$_];
        }
    }
    $call->print_info( $out, qq{\n===Statement end===} );

    return $self;
}

sub show_sql_rv {
    my ( $self, $call, $obj, $arg, $rv ) = @_;

    $call->print_info( 'Affected rows: ',
        defined $rv ? $rv : '-UNKNOWN-', q{.} );

    return $self;
}

sub show_update {
    my ( $self, $call, $obj, $arg, $rv ) = @_;

    $call->print_info( 'Updated rows: ',
        defined $rv ? $rv : '-UNKNOWN-', q{.} );

    return $self;
}

sub _callstack {
    my ( $self, $start_from ) = @_;

    if ( !( defined $start_from && $start_from ne q{} ) ) {
        return [];
    }

    my @callstack = ();
    my $started   = 0;
    my $i         = 0;
CALLER:
    while ( ++$i ) {
        my ($package, $filename,  $line,     $subroutine,
            $hasargs, $wantarray, $evaltext, $is_require,
            $hints,   $bitmask,   $hinthash
        ) = caller $i;

        if ( !defined $filename ) {
            last CALLER;
        }
        elsif ( $subroutine eq $start_from ) {
            $started = 1;
        }
        elsif ( !$started ) {
            next CALLER;
        }

        push
            @callstack,
            {
            package    => $package,
            filename   => $filename,
            line       => $line,
            subroutine => $subroutine,
            hasargs    => $hasargs,
            wantarray  => $wantarray
            };
    }
    return \@callstack;
}

sub _select_handler {
    my ( $self, $handlers, $method, $default, $default_value ) = @_;

    return
          ref $handlers ne 'HASH' ? $handlers
        : exists $handlers->{$method}  ? $handlers->{$method}
        : exists $handlers->{$default} ? $handlers->{$default}
        :                                $default_value;
}

sub _is_delete {
    my ( $self, $sql ) = @_;
    return $sql =~ /\A[\r\n\s]*?DELETE\s/ixms ? 1 : 0;
}

sub _is_insert {
    my ( $self, $sql ) = @_;
    return $sql =~ /\A[\r\n\s]*?INSERT\s/ixms ? 1 : 0;
}

sub _is_select {
    my ( $self, $sql ) = @_;
    return $sql =~ /\A[\r\n\s]*?SELECT\s/ixms ? 1 : 0;
}

sub _is_update {
    my ( $self, $sql ) = @_;
    return $sql =~ /\A[\r\n\s]*?UPDATE\s/ixms ? 1 : 0;
}

1;

__END__

=pod

=head1 NAME

Debug::DBI - Tool to monitor/dump DBI calls

=head1 SYNOPSIS

  To print all DBI calls incl. SQL statements and query results to
  stdout.

  In perl script:

    use Debug::DBI::Default;

  or from command line:

    perl -MDebug::DBI::Default <script name>

  For fine-graind control:

    use Log::Any::Adapter
    use DBI;
    use Debug::DBI

    Log::Any::Adapter->set(
        {
            category => 'Debug::DBI'
        },
        'FileHandle',
    };

    our $obj = Debug::DBI->new(
       formatter     => Debug::DBI::Formatter->new,
       hide_password => 0,
       constraint => {
          'default' => sub {
              my ($call) = @_;

              # ...

              return 1;
          }
       }
    )->install;

=head1 DESCRIPTION

This module allows you to trace and dump DBI calls.

TODO
 - Formatter:
   - support multi-line values
   - limit column width
 - DBI
   - Error handling: better support for RaiseError = 0; (Check return value and dbh->errstr!)


=head1 ATTRIBUTES

=head2 C<constraint>

=head2 C<formatter>

=head2 C<hide_password>

=head2 C<log_category>

=head2 C<max_rows>

=head2 C<patch_map>

=head2 C<patches>

=head2 C<wrap_orig>

=head1 METHODS

=head1 SEE ALSO

L<Log::Any|Log::Any>, L<Log::Any::Adapter|Log::Any::Adapter>

=head1 AUTHOR

Henry Tang

=head1 COPYRIGHT & LICENSE

Copyright (C) 2011 Henry Tang

Debug::DBI is provided "as is" and without any express or
implied warranties, including, without limitation, the implied warranties
of merchantibility and fitness for a particular purpose.

This program is free software, you can redistribute it and/or modify it
under the terms of the Artistic License version 2.0.

=cut
