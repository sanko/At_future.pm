package At::Utils 1.0 {
    use v5.36;
    use parent 'Exporter';
    #
    our %EXPORT_TAGS = ( all => [ our @EXPORT_OK = qw[byteLength graphemeLength namespace2package] ] );
    #
    sub byteLength($str) {
        use bytes;
        length $str;
    }

    sub graphemeLength ($str) {    # https://www.perl.com/pub/2012/05/perlunicook-string-length-in-graphemes.html/
        my $count = 0;
        $count++ while $str =~ /\X/g;
        return $count;
    }

    sub namespace2package ($fqdn) {
        my $namespace = $fqdn =~ s[[#\.]][::]gr;
        'At::Lexicon::' . $namespace;
    }
};
1;
__END__
=encoding utf-8

=head1 NAME

At - The AT Protocol for Social Networking

=head1 SYNOPSIS

    use At::Utils qw[graphemeLength];
    my $bsky = At->new( service => 'https://bsky.social' );
    $bsky->post( text => 'Hi.' );

=head1 DESCRIPTION

Just random stuff in here, folks.

=head1 Functions

You may import all of these with the C<:all> tag or import them by name.

=head2 C<byteLength( ... )>

Returns the string length in bytes.

=head2 C<graphemeLength( ... )>

Returns the string length in graphemes.

=head2 C<namespace2package( ... )>

Takes a lexicon NSID and converts it to a perl package name under our namespace.

=head1 See Also

L<App::bsky> - Bluesky client on the command line

L<https://docs.bsky.app/docs/api/>

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2. Other copyrights, terms, and conditions may apply to data transmitted through this module.

=head1 AUTHOR

Sanko Robinson E<lt>sanko@cpan.orgE<gt>

=begin stopwords

atproto Bluesky

=end stopwords

=cut
