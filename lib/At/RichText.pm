package At::RichText 1.0 {
    use v5.38;
    use feature 'class';
    no warnings qw[experimental::builtin experimental::class];
    use lib '../../lib';
    use At::Utils;
    use utf8;
    use overload '""' => sub( $s, $q, $u ) {'TODO'};
    #
    sub new ( $class, %args ) {
        $args{text} //= '';
        $args{facets} = [ map { builtin::blessed $_ ? $_ : At::Lexicon::app::bsky::richtext::facet->new(%$_) } @{ $args{facets} } ];
        bless \%args, $class;
    }
    sub text($s)           { $s->{text} }
    sub facets($s)         { $s->{facets} }
    sub length($s)         { At::Utils::byteLength $s->{text} }
    sub graphemeLength($s) { At::Utils::graphemeLength $s->{text} }

    sub insert( $s, $insert_index, $insert_text ) {
        use bytes;
        substr $s->{text}, $insert_index, 0, $insert_text;
        if ( @{ $s->{facets} } ) {
            my $numCharsAdded = At::Utils::byteLength($insert_text);
            for my $ent ( @{ $s->{facets} } ) {

                # Scenario A (before)
                if ( $insert_index <= $ent->index->byteStart ) {
                    $ent->index->byteStart( $ent->index->byteStart + $numCharsAdded );
                    $ent->index->byteEnd( $ent->index->byteEnd + $numCharsAdded );
                }

                # Scenario B (after)
                elsif ( $insert_index >= $ent->index->byteStart && $insert_index < $ent->index->byteEnd ) {    # move end by num added
                    $ent->index->byteEnd( $ent->index->byteEnd + $numCharsAdded );
                }

                # Scenario C (after)
                # noop?
            }
        }
        $s;
    }

    sub delete ( $s, $remove_start, $remove_end ) {
        use bytes;
        substr( $s->{text}, $remove_start, $remove_end - $remove_start, '' );
        if ( @{ $s->{facets} } ) {
            my $numCharsRemoved = $remove_end - $remove_start;
            for my $ent ( @{ $s->{facets} } ) {

                # Scenario A (entirely outer)
                if ( $remove_start <= $ent->index->byteStart && $remove_end >= $ent->index->byteEnd ) {
                    $ent->index->byteStart(0);
                    $ent->index->byteEnd(0);
                }

                # Scenario B (entirely after)
                elsif ( $remove_start > $ent->index->byteEnd ) {

                    # noop
                }

                # Scenario C (partially after)
                elsif ( $remove_start > $ent->index->byteStart && $remove_start <= $ent->index->byteEnd && $remove_end > $ent->index->byteEnd ) {

                    # move end to remove start
                    $ent->index->byteEnd($remove_start);
                }

                # Scenario D (entirely inner)
                elsif ( $remove_start >= $ent->index->byteStart && $remove_end <= $ent->index->byteEnd ) {

                    # move end by num removed
                    $ent->index->byteEnd( $ent->index->byteEnd - $numCharsRemoved );
                }

                # Scenario E (partially before)
                elsif ( $remove_start < $ent->index->byteStart && $remove_end >= $ent->index->byteStart && $remove_end <= $ent->index->byteEnd ) {

                    # move start to remove-start index, move end by num removed
                    $ent->index->byteStart($remove_start);
                    $ent->index->byteEnd( $ent->index->byteEnd - $numCharsRemoved );
                }

                # Scenario F (entirely before)
                elsif ( $remove_end < $ent->index->byteStart ) {

                    # move both by num removed
                    $ent->index->byteStart( $ent->index->byteStart - $numCharsRemoved );
                    $ent->index->byteEnd( $ent->index->byteEnd - $numCharsRemoved );
                }

                # filter out any facets that were made irrelevant
                $s->{facets} = [ grep { $_->index->byteStart < $_->index->byteEnd } @{ $s->{facets} } ];
            }
        }
        $s;
    }
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

Clients to Bluesky should produce facets using parsers. It's perfectly valid to use a syntax (including markdown or
HTML) but that syntax should be stripped out of the text before publishing. Whew... anyway, this package attempts to do
all of that for you.

=head1 Methods

When we sanitize rich text, we have to update the entity indices as the text is modified. This can be modeled as
C<inserts()> and C<deletes()> of the rich text string. The possible scenarios are outlined below, along with their
expected behaviors.

NOTE: Slices are start inclusive, end exclusive

This package is object oriented so you'll need to create an initial rich text object to work with.

=head2 C<new( ... )>

    my $rt = At::RichText->new( text=> 'hello world' );

Creates a new object for you.

Expected parameters include:

=over

=item C<text>

Initial plain text for display.

=item C<facets>

List of C<At::Lexicon::app::bsky::richtext::facet> objects. This list is coerced if items aren't blessed.

=back

=head2 C<insert( ... )>

    $rt->insert( 0, 'This is more text' );

Inserts text at a given position and adjusts facets automatically.

Expected parameters include:

=over

=item C<index> - required

=item C<text> - required

=back

Target string:

   0 1 2 3 4 5 6 7 8 910   // string indices
   h e l l o   w o r l d   // string value
       ^-------^           // target slice {start: 2, end: 7}

Scenarios:

    A: ^                       // insert "test" at 0
    B:        ^                // insert "test" at 4
    C:                 ^       // insert "test" at 8

    A = before           -> move both by num added
    B = inner            -> move end by num added
    C = after            -> noop

Results:

    A: 0 1 2 3 4 5 6 7 8 910   // string indices
       t e s t h e l l o   w   // string value
                   ^-------^   // target slice {start: 6, end: 11}

    B: 0 1 2 3 4 5 6 7 8 910   // string indices
       h e l l t e s t o   w   // string value
           ^---------------^   // target slice {start: 2, end: 11}

    C: 0 1 2 3 4 5 6 7 8 910   // string indices
       h e l l o   w o t e s   // string value
           ^-------^           // target slice {start: 2, end: 7}

=head2 C<delete( ... )>

    $rt->delete( 0, 5 );

Deletes text starting at a given position through another position and adjusts facets automatically.

Expected parameters include:

=over

=item C<start> - required

=item C<end> - required

=back

Target string:

       0 1 2 3 4 5 6 7 8 910   // string indices
       h e l l o   w o r l d   // string value
           ^-------^           // target slice {start: 2, end: 7}

Scenarios:

    A: ^---------------^       // remove slice {start: 0, end: 9}
    B:               ^-----^   // remove slice {start: 7, end: 11}
    C:         ^-----------^   // remove slice {start: 4, end: 11}
    D:       ^-^               // remove slice {start: 3, end: 5}
    E:   ^-----^               // remove slice {start: 1, end: 5}
    F: ^-^                     // remove slice {start: 0, end: 2}

    A = entirely outer   -> delete slice
    B = entirely after   -> noop
    C = partially after  -> move end to remove-start
    D = entirely inner   -> move end by num removed
    E = partially before -> move start to remove-start index, move end by num removed
    F = entirely before  -> move both by num removed

Results:

    A: 0 1 2 3 4 5 6 7 8 910   // string indices
       l d                     // string value
                               // target slice (deleted)

    B: 0 1 2 3 4 5 6 7 8 910   // string indices
       h e l l o   w           // string value
           ^-------^           // target slice {start: 2, end: 7}

    C: 0 1 2 3 4 5 6 7 8 910   // string indices
       h e l l                 // string value
           ^-^                 // target slice {start: 2, end: 4}

    D: 0 1 2 3 4 5 6 7 8 910   // string indices
       h e l   w o r l d       // string value
           ^---^               // target slice {start: 2, end: 5}

    E: 0 1 2 3 4 5 6 7 8 910   // string indices
       h   w o r l d           // string value
         ^-^                   // target slice {start: 1, end: 3}

    F: 0 1 2 3 4 5 6 7 8 910   // string indices
       l l o   w o r l d       // string value
       ^-------^               // target slice {start: 0, end: 5}

=head1 Rich Text Manipulation

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

=head1 See Also

L<At>

L<https://www.pfrazee.com/blog/why-facets>

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
