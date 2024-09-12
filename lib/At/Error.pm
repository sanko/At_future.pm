package At::Error 1.0 {
    use v5.38;
    use Carp;
    use parent 'Exporter';
    our @EXPORT = qw[throw register];
    use overload
        bool => sub {0},
        '""' => sub ( $s, $u, $q ) { $s->[0] };

    # TODO: What should I do with description? Nothing?
    sub new ( $class, $message, $description //= () ) {
        my @stack;
        my $i = 1;    # Skip one
        while ( my %i = Carp::caller_info( ++$i ) ) {
            next if $i{pack} eq __PACKAGE__;
            push @stack, \%i;
        }
        bless [ $message, $description, 0, \@stack ], $class;
    }

    sub throw($s) {
        my ( undef, $file, $line ) = caller();
        ++$s->[2];    # Interesting. Maybe.
        die join "\n\t", sprintf( q[%s at %s line %d], $s->[0], $file, $line ),
            map { sprintf q[%s called at %s line %d], $_->{sub_name}, $_->{file}, $_->{line} } @{ $s->[3] };
    }

    sub register($class) {
        my ($from) = caller;
        no strict 'refs';
        *{ $from . '::' . $class } = sub ( $message, $description //= () ) { ( __PACKAGE__ . '::_' . $class )->new( $message, $description ) };
        push @{ __PACKAGE__ . '::_' . $class . '::ISA' }, __PACKAGE__;
    }
}
1;
__END__
=encoding utf-8

=head1 NAME

At::Error - Throwable Errors

=head1 SYNOPSIS

    use At::Error;    # You shouldn't be here yet.
    register 'SomeError';

    sub yay {

        # Some stuff here ...
        return SomeError('Oh, no!') if 'pretend someting bad happened';
        return 1;
    }
    my $okay = yay();
    throw $okay unless $okay;    # Errors overload bool to be false

=head1 DESCRIPTION

You shouldn't be here.

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2. Other copyrights, terms, and conditions may apply to data transmitted through this module.

=head1 AUTHOR

Sanko Robinson E<lt>sanko@cpan.orgE<gt>

=begin stopwords

atproto

=end stopwords

=cut
