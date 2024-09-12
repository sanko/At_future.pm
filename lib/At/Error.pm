package At::Error 1.0 {
    use v5.38;
    use overload
        bool => sub {0},
        '""' => sub ( $s, $u, $q ) { $s->{message} // 'Unknown error' };
    sub new ( $class, $args ) { bless $args, $class }
}
1;
__END__
=encoding utf-8

=head1 NAME

At::Error - Throwable Error

=head1 SYNOPSIS

    use At; # You shouldn't be here yet.

=head1 DESCRIPTION

This is just a placeholder for now.

At some point, errors will generate objects rather than just L<confess>ing.

=head1 See Also

L<At::UserAgent::Tiny> - default subclass based on L<HTTP::Tiny>

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2. Other copyrights, terms, and conditions may apply to data transmitted through this module.

=head1 AUTHOR

Sanko Robinson E<lt>sanko@cpan.orgE<gt>

=begin stopwords

atproto ing

=end stopwords

=cut
