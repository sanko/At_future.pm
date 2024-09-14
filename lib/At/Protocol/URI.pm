package At::Protocol::URI 1.0 {    # https://atproto.com/specs/at-uri-scheme

    # https://github.com/bluesky-social/atproto/blob/main/packages/syntax/src/aturi.ts
    use v5.38;
    no warnings qw[experimental::builtin experimental::try];
    use At::Error            qw[register throw];
    use At::Protocol::DID    qw[ensureValidDid ensureValidDidRegex];
    use At::Protocol::Handle qw[ensureValidHandle ensureValidHandleRegex];
    use At::Protocol::NSID   qw[ensureValidNsid ensureValidNsidRegex];
    use feature 'try';
    use parent -norequire => 'Exporter';
    use overload
        '""' => sub ( $s, $u, $q ) {
        $s->as_string;
        };
    our %EXPORT_TAGS = ( all => [ our @EXPORT_OK = qw[ensureValidAtUri ensureValidAtUriRegex] ] );

    sub ATP_URI_REGEX () {

        #   proto-    --did--------------   --name----------------   --path----   --query--   --hash--
        qr/^(at:\/\/)?((?:did:[a-z0-9:%-]+)|(?:[a-z0-9][a-z0-9.:-]*))(\/[^?#\s]*)?(\?[^#\s]+)?(#[^\s]+)?$/i;
    }

    sub RELATIVE_REGEX () {

        #   --path-----   --query--  --hash--
        qr/^(\/[^?#\s]*)?(\?[^#\s]+)?(#[^\s]+)?$/i;
    }

    sub new( $class, $uri, $base //= () ) {
        my $parsed;
        if ( defined $base ) {
            $parsed = _parse($base);
            $parsed // throw InvalidAtUriError( 'Invalid AT URI: ' . $base );
            my $relativep = _parseRelative($uri);
            $relativep // throw InvalidAtUriError( 'Invalid path: ' . $uri );
            %$parsed = ( %$parsed, %$relativep );
        }
        else {
            $parsed = _parse($uri);
            $parsed // throw InvalidAtUriError( 'Invalid AT URI: ' . $uri );
        }
        bless $parsed, $class;
    }

    sub _parse($uri) {
        my @res = $uri =~ ATP_URI_REGEX();
        @res or return;
        { hash => $res[4] // '', host => $res[1] // '', pathname => $res[2] // '', searchParams => At::Protocol::URI::_query->new( $res[3] // '' ) };
    }

    sub _parseRelative($uri) {
        my @res = $uri =~ RELATIVE_REGEX();
        @res or return;
        { hash => $res[2] // '', pathname => $res[0] // '', searchParams => At::Protocol::URI::_query->new( $res[1] // '' ) };
    }

    sub as_string($s) {
        my $path = $s->pathname // '';
        $path = '/' . $path if $path !~ m[^/];
        my $qs = $s->search;
        $qs = '?' . $qs if length $qs && $qs !~ m[^\?];
        my $hash = $s->hash;
        $hash = '#' . $hash if length $hash && $hash !~ m[^#];
        join '', grep {defined} $s->origin, $path, $qs, $hash;
    }

    sub make ( $handle_r_did, $collection //= (), $rkey //= () ) {
        At->new( join '/', grep {defined} $handle_r_did, $collection, $rkey );
    }
    sub protocol ($s)             {'at:'}
    sub origin($s)                { $s->protocol . '//' . $s->host }
    sub host ( $s, $v //= () )    { $v // return $s->{host}; $s->{host} = $v }
    sub pathname( $s, $v //= () ) { $v // return $s->{pathname}; $s->{pathname} = $v }

    sub search ( $s, $v //= () ) {
        $v // return $s->{searchParams};
        $s->{searchParams}->parse_params($v);
    }
    sub hash ( $s, $v //= () ) { $v // return $s->{hash}; $s->{hash} = $v; }

    sub collection ( $s, $v //= () ) {
        return [ grep {length} split '/', $s->pathname ]->[0] || '' unless defined $v;
        my @parts = split '/', $s->pathname;
        $parts[0] = $v;
        $s->pathname( join '/', @parts );
    }

    sub rkey ( $s, $v //= () ) {
        return [ grep {length} split '/', $s->pathname ]->[1] || '' unless defined $v;
        my @parts = split '/', $s->pathname;
        $parts[0] //= 'undefined';
        $parts[1] = $v;
        $s->pathname( join '/', @parts );
    }

    #~ Validation utils from https://github.com/bluesky-social/atproto/blob/main/packages/syntax/src/aturi_validation.ts
    #~  Human-readable constraints on ATURI:
    #~    - following regular URLs, a 8KByte hard total length limit
    #~    - follows ATURI docs on website
    #~       - all ASCII characters, no whitespace. non-ASCII could be URL-encoded
    #~       - starts "at://"
    #~       - "authority" is a valid DID or a valid handle
    #~       - optionally, follow "authority" with "/" and valid NSID as start of path
    #~       - optionally, if NSID given, follow that with "/" and rkey
    #~       - rkey path component can include URL-encoded ("percent encoded"), or:
    #~           ALPHA / DIGIT / "-" / "." / "_" / "~" / ":" / "@" / "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
    #~           [a-zA-Z0-9._~:@!$&'\(\)*+,;=-]
    #~       - rkey must have at least one char
    #~       - regardless of path component, a fragment can follow  as "#" and then a JSON pointer (RFC-6901)
    sub ensureValidAtUri($uri) {
        my $fragmentPart;
        my @uriParts = split '#', $uri, -1;    # negative limit, ftw
        throw InvalidAtUriError('ATURI can have at most one "#", separating fragment out') if scalar @uriParts > 2;
        $fragmentPart = $uriParts[1];
        $uri          = $uriParts[0];

        # Check that all chars are boring ASCII
        throw InvalidAtUriError('Disallowed characters in ATURI (ASCII)') unless $uri =~ /^[a-zA-Z0-9._~:@!\$&')(*+,;=%\/-]*$/;
        #
        my @parts = split /\//, $uri, -1;      # negative limit, ftw
        throw InvalidAtUriError('ATURI must start with "at://"') if scalar @parts >= 3 && ( $parts[0] ne 'at:' || length $parts[1] );
        throw InvalidAtUriError('ATURI requires at least method and authority sections') if scalar @parts < 3;
        try {
            if   ( $parts[2] =~ m/^did:/ ) { ensureValidDid( $parts[2] ); }
            else                           { ensureValidHandle( $parts[2] ) }
        }
        catch ($err) {
            throw InvalidAtUriError('ATURI authority must be a valid handle or DID');
        };
        if ( scalar @parts >= 4 ) {
            if ( !length $parts[3] ) {
                throw InvalidAtUriError('ATURI can not have a slash after authority without a path segment');
            }
            try {
                ensureValidNsid( $parts[3] );
            }
            catch ($err) {
                throw InvalidAtUriError('ATURI requires first path segment (if supplied) to be valid NSID')
            }
        }
        if ( scalar @parts >= 5 ) {
            throw InvalidAtUriError('ATURI can not have a slash after collection, unless record key is provided') if !length $parts[4]

            # would validate rkey here, but there are basically no constraints!
        }
        throw InvalidAtUriError('ATURI path can have at most two parts, and no trailing slash') if scalar @parts >= 6;
        throw InvalidAtUriError('ATURI fragment must be non-empty and start with slash')        if scalar @uriParts >= 2 && !defined $fragmentPart;
        if ( defined $fragmentPart ) {
            throw InvalidAtUriError('ATURI fragment must be non-empty and start with slash')
                if length $fragmentPart == 0 || substr( $fragmentPart, 0, 1 ) ne '/';

            # NOTE: enforcing *some* checks here for sanity. Eg, at least no whitespace
            throw InvalidAtUriError( 'Disallowed characters in ATURI fragment (ASCII)' . $fragmentPart )
                if $fragmentPart !~ /^\/[a-zA-Z0-9._~:@!\$&')(*+,;=%[\]\/-]*$/;
        }
        throw InvalidAtUriError('ATURI is far too long') if length $uri > 8 * 1024;
        1;
    }

    sub ensureValidAtUriRegex($uri) {

        #~ simple regex to enforce most constraints via just regex and length.
        my $aturiRegex
            = qr/^at:\/\/(?<authority>[a-zA-Z0-9._:%-]+)(\/(?<collection>[a-zA-Z0-9-.]+)(\/(?<rkey>[a-zA-Z0-9._~:@!\$&%')(*+,;=-]+))?)?(#(?<fragment>\/[a-zA-Z0-9._~:@!\$&%')(*+,;=\-[\]\/\\]*))?$/;
        my ($rm) = $uri =~ $aturiRegex;
        throw InvalidAtUriError(q[ATURI didn't validate via regex]) if !$rm || !keys %+;
        my %groups = %+;
        try {
            ensureValidHandleRegex( $groups{authority} )
        }
        catch ($err) {
            try {
                ensureValidDidRegex( $groups{authority} )
            }
            catch ($err) {
                throw InvalidAtUriError('ATURI authority must be a valid handle or DID')
            }
        }
        if ( defined $groups{collection} ) {
            try {
                ensureValidNsidRegex( $groups{collection} )
            }
            catch ($err) {
                throw InvalidAtUriError('ATURI collection path segment must be a valid NSID');
            }
        }
        throw InvalidAtUriError('ATURI is far too long') if length $uri > 8 * 1024;
        1;
    }
    register 'InvalidAtUriError';
};
package    #
    At::Protocol::URI::_query 1.0 {
    use v5.38;
    use URI::Escape qw[uri_escape_utf8 uri_unescape];
    use overload
        '""' => sub ( $s, $u, $q ) {
        $s->as_string;
        };

    sub new( $class, $qs ) {
        my $s = bless [], $class;
        $s->parse_params($qs);
        $s;
    }

    sub parse_params( $s, $qs ) {
        $qs =~ s[^\?+][];    # Just in case
        @$s = map {
            [ map { uri_unescape($_) } split /=/, $_, 2 ]
        } split /[&;]/, $qs;
    }

    sub get_param( $s, $name ) {
        map { $_->[1] } grep { $_->[0] eq $name } @$s;
    }

    sub add_param( $s, $name, @v ) {
        $name = uri_unescape $name;
        push @$s, [ $name, uri_unescape shift @v ] while @v;
        1;
    }

    sub set_param( $s, $name, @v ) {
        $name = uri_unescape $name;
        for my $slot ( grep { $_->[0] eq $name } @$s ) {
            $slot->[1] = uri_unescape shift @v;
            @v || last;
        }
        push @$s, [ $name, uri_unescape shift @v ] while @v;
        1;
    }

    sub delete_param( $s, $name ) {
        $name = uri_unescape $name;
        @$s   = grep { $_->[0] ne $name } @$s;
    }

    sub replace_param( $s, $name, @v ) {
        $s->delete_param($name);
        $name = uri_unescape $name;
        push @$s, [ $name, uri_unescape shift @v ] while @v;
        1;
    }

    sub reset($s) {
        !( @$s = () );
    }

    sub as_string( $s, $sep //= '&' ) {
        join $sep, map { join '=', uri_escape_utf8( $_->[0] ), uri_escape_utf8( $_->[1] ) } @$s;
    }
    };
1;
__END__
=encoding utf-8

=head1 NAME

At::Protocol::URI - AT Protocol URI Validation

=head1 SYNOPSIS

    use At::Protocol::URI qw[:all];
    try {
        ensureValidNSID( 'net.users.bob.ping' );
    }
    catch($err) {
        ...; # do something about it
    }

=head1 DESCRIPTION

Namespaced Identifiers (NSIDs) are used to reference Lexicon schemas for records, XRPC endpoints, and more.

The basic structure and semantics of an NSID are a fully-qualified hostname in Reverse Domain-Name Order, followed by a
simple name. The hostname part is the B<domain authority>, and the final segment is the B<name>.

This package aims to validate them.

=head1 Functions

You may import functions by name or with the C<:all> tag.

=head2 C<new( ... )>

Verifies an NSID and creates a new object containing it.

    my $nsid = At::Protocol::NSID->new( 'com.example.fooBar' );

On success, an object is returned that will stringify to the NSID itself.

=head2 C<parse( ... )>

    my $nsid = parse( 'com.example.fooBar' );

Wrapper around C<new(...)> for the sake of compatibility.

=head2 C<create( ... )>

    my $nsid = create( 'alex.example.com' );

Parses a 'normal' (sub)domain name and creates an NSID object.

=head2 C<authority( )>

    my $auth = $nsid->authority;

Returns the domain authority of the NSID.

=head2 C<name( )>

    my $name = $nsid->name;

Returns the name from the NSID.

=head2 C<isValid( ... )>

    my $ok = isValid( 'com.exa💩ple.thing' );

Returns a boolean value indicating whether the given NSID is valid and can be parsed.

=head2 C<ensureValidNsid( ... )>

    ensureValidNsid( '.com.example.wrong' );

Validates an NSID. Throws errors on failure and returns a true value on success.

=head2 C<ensureValidNsidRegex( ... )>

    ensureValidNsidRegex( 'com.example.right' );

Validates an NSID with cursory regex provided by the AT protocol designers. Throws errors on failure and returns a true
value on success.

=head1 See Also

L<https://atproto.com/specs/nsid>

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
