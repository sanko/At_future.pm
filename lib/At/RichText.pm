package At::RichText 1.0 {
    use v5.38;
    use feature 'class';
    no warnings qw[experimental::builtin experimental::class];
    use lib '../../lib';
    use At::Utils;
    use overload '""' => sub( $s, $q, $u ) {'TODO'};

    class At::RichText 1.0 {
        field $text : param;
        field $facets : param //= [];
        #
        ADJUST {
            $facets = [ map { builtin::blessed $_ ? $_ : At::RichText::Facet->new(%$_) } @$facets ];

            #~ $facets = [ map { builtin::blessed $_ ? $_ : defined $_->{'$type'} ?
            #~ (At::Utils::namespace2package( $_->{'$type'} )//'')->new(%$_) : $_ }
            #~ @$facets ];
        }

        # Accessors didn't show up until 5.40...
        method text()           {$text}
        method facets()         {$facets}
        method length()         { At::Utils::byteLength $text }
        method graphemeLength() { At::Utils::graphemeLength $text }
        #
        method insert( $insert_index, $insert_text ) {
            use bytes;
            substr $text, $insert_index, 0, $insert_text;
            return $self if !@$facets;    # don't bother
            my $numCharsAdded = At::Utils::byteLength($insert_text);
            for my $ent (@$facets) {

                # See comment at op of https://github.com/bluesky-social/atproto/blob/main/packages/api/src/rich-text/rich-text.ts
                #  for labels of each scenario.
                # Scenario A (before)
                if ( $insert_index <= $ent->index->byteStart ) {
                    $ent->index->byteStart( $ent->index->byteStart + $numCharsAdded );
                    $ent->index->byteEnd( $ent->index->byteEnd + $numCharsAdded );
                }
            }
        }
    }

    class At::RichText::Facet::byteSlice 1.0 {
        field $byteStart : param;
        field $byteEnd : param;

        # Accessors didn't show up until 5.40...
        method byteStart( $v //= () ) { $byteStart = $v if defined $v; $byteStart }
        method byteEnd( $v   //= () ) { $byteEnd   = $v if defined $v; $byteEnd }
    }

    class At::RichText::Facet 1.0 {
        field $index : param;
        field $features : param;    # Array of lex:app.bsky.richtext.facet#mention, #link, or #tag

        # Accessors didn't show up until 5.40...
        method index() {$index}
        #
        ADJUST {
            $index    = At::RichText::Facet::byteSlice->new(%$index) unless builtin::blessed $index;
            $features = [
                map {
                    return $_ if builtin::blessed $_;
                    my $type = $_->{'$type'} ? At::Utils::namespace2package( $_->{'$type'} ) : ();
                    defined $type ? $type->(%$_) : $_
                } @$features
            ];
        }

#~ AppBskyRichtextFacet: {
#~ lexicon: 1,
#~ id: 'app.bsky.richtext.facet',
#~ defs: {
#~ main: {
#~ type: 'object',
#~ description: 'Annotation of a sub-string within rich text.',
#~ required: ['index', 'features'],
#~ properties: {
#~ index: {
#~ type: 'ref',
#~ ref: 'lex:app.bsky.richtext.facet#byteSlice',
#~ },
#~ features: {
#~ type: 'array',
#~ items: {
#~ type: 'union',
#~ refs: [
#~ 'lex:app.bsky.richtext.facet#mention',
#~ 'lex:app.bsky.richtext.facet#link',
#~ 'lex:app.bsky.richtext.facet#tag',
#~ ],
#~ },
#~ },
#~ },
#~ },
#~ mention: {
#~ type: 'object',
#~ description:
#~ "Facet feature for mention of another account. The text is usually a handle, including a '@' prefix, but the facet reference is a DID.",
#~ required: ['did'],
#~ properties: {
#~ did: {
#~ type: 'string',
#~ format: 'did',
#~ },
#~ },
#~ },
#~ link: {
#~ type: 'object',
#~ description:
#~ 'Facet feature for a URL. The text URL may have been simplified or truncated, but the facet reference should be a complete URL.',
#~ required: ['uri'],
#~ properties: {
#~ uri: {
#~ type: 'string',
#~ format: 'uri',
#~ },
#~ },
#~ },
#~ tag: {
#~ type: 'object',
#~ description:
#~ "Facet feature for a hashtag. The text usually includes a '#' prefix, but the facet reference should not (except in the case of 'double hash tags').",
#~ required: ['tag'],
#~ properties: {
#~ tag: {
#~ type: 'string',
#~ maxLength: 640,
#~ maxGraphemes: 64,
#~ },
#~ },
#~ },
#~ byteSlice: {
#~ type: 'object',
#~ description:
#~ 'Specifies the sub-string range a facet feature applies to. Start index is inclusive, end index is exclusive. Indices are zero-indexed, counting bytes of the UTF-8 encoded text. NOTE: some languages, like Javascript, use UTF-16 or Unicode codepoints for string slice indexing; in these languages, convert to byte arrays before working with facets.',
#~ required: ['byteStart', 'byteEnd'],
#~ properties: {
#~ byteStart: {
#~ type: 'integer',
#~ minimum: 0,
#~ },
#~ byteEnd: {
#~ type: 'integer',
#~ minimum: 0,
#~ },
#~ },
#~ },
#~ },
#~ },
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
HTML) but that syntax should be stripped out of the text before publishing. Whew... anyway, this package attempts to do
all of that for you.

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
