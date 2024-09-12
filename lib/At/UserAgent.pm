package At::UserAgent 1.0 {
    use v5.38;
    sub new  {...}
    sub get  {...}
    sub post {...}
    sub _set_session ( $s, $session ) {...}
    sub session      ($s)             {...}
    sub ratelimit    ($s)             {...}
}
1;
__END__
=encoding utf-8

=head1 NAME

At::UserAgent - Generic HTTP Client Base Class

=head1 SYNOPSIS

    package At::UserAgent::Custom 1.0 {
        use v5.38;
        use parent -norequire, 'At::UserAgent';
        #
        sub ...
    }

=head1 DESCRIPTION

Internal representation of an HTTPs client. You shouldn't be here.

=head1 See Also

L<At::UserAgent::Tiny> - default subclass based on L<HTTP::Tiny>

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
