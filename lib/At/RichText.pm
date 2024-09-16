package At::RichText 1.0 {
    use v5.38;
};
1;
__END__
=encoding utf-8

=head1 NAME

At::RichText - Rich Text Manipulation

=head1 SYNOPSIS

    use At::RichText;
    # TODO

=head1 DESCRIPTION

Rather than allowing a markup language (html, markdown, etc.), posts in Bluesky use so called 'rich text' to handle
links, mentions, and other kinds of decorated text.

Let's take a look at how this works. Say you want to decorate this string:

    Go to this site

We can number the positions in the string as follows:

    G  o     t  o     t  h  i  s     s  i  t  e
    0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15

We want to turn characters C<6> through C<14> into a link. To do that, we assert a link with C<byteStart>: C<6> and
C<byteEnd>: C<15> and a C<uri> of C<https://example.com>.

    G  o     t  o     t  h  i  s     s  i  t  e
    0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
                     ^---------------------------^
                      link to https://example.com

Note that the range has an inclusive start and exclusive end. That means the C<end> number goes C<1> past what you
might expect.

Exclusive-end helps the math stay consistent. If you subtract the end from the start, you get the correct length of the
target string. In this case, C<15-6 = 9>, which is the length of the "C<this site>" string.

In a post, it looks like this:

    {   text   => 'Go to this site',
        facets => [
            {   index    => { byteStart => 6, byteEnd => 15 },
                features => [ { '$type' => 'app.bsky.richtext.facet#link', uri => 'https://example.com' } ]
            }
        ]
    };

=head2 Features

The facet's features establish what kind of decorations are being applied to the range. There are three supported
feature types:

=over

=item C<app.bsky.richtext.facet#link>

A link to some resource. Has the C<uri> attribute.

=item C<app.bsky.richtext.facet#mention>

A mention of a user. Produces a notification for the mentioned user. Has the C<did> attribute.

=item C<app.bsky.richtext.facet#tag>

A hashtag. Has the C<tag> attribute.

=back

Facets can not overlap. It's recommended that renderers sort them by C<byteStar>t and discard any facets which overlap
each other. The C<features> attribute is an array to support multiple decorations on a given range.

=head2 Text encoding and indexing

Strings in the network are UTF-8 encoded. Facet ranges are indexed using byte offsets into the UTF-8 encoding.

It's important to pay attention to this when working with facets. Incorrect indexing will produce bad data.

To understand this fully, let's look at some of the kinds of indexing that Unicode supports:

=over

=item code units

The "atom" of an encoding. In UTF-8, this is a byte. In UTF-16, this is two bytes. In UTF-32, this is four bytes.

=item code points

The "atom" of a unicode string. This is the same across all encodings; that is, a code-point index in UTF-8 is the same
as a code-point index in UTF-16 or UTF-32.

=item Graphemes

The visual "atom" of text -- what we think of as a "character". Graphemes are made of multiple code-points.

=back

Bluesky uses UTF-8 code units to index facets. Put another way, it uses byte offsets into UTF-8 encoded strings. This
means you must handle the string in UTF-8 to produce valid indexes.

=head1 Producing Facets

Clients to Bluesky should produce facets using parsers. It's perfectly valid to use a syntax (including markdown or
HTML) but that syntax should be stripped out of the text before publishing.

=head1 See Also

L<At>

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2. Other copyrights, terms, and conditions may apply to data transmitted through this module.

=head1 AUTHOR

Sanko Robinson E<lt>sanko@cpan.orgE<gt>

=begin stopwords

atproto unicode encodings html hashtag

=end stopwords

=cut
