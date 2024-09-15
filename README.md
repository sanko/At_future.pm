[![Actions Status](https://github.com/sanko/At_future.pm/actions/workflows/ci.yml/badge.svg)](https://github.com/sanko/At_future.pm/actions) [![MetaCPAN Release](https://badge.fury.io/pl/At.svg)](https://metacpan.org/release/At)
# NAME

At - The AT Protocol for Social Networking

# SYNOPSIS

```perl
use At;
my $bsky = At->new( service => 'https://bsky.social' );
$bsky->post( text => 'Hi.' );
```

# DESCRIPTION

You shouldn't need to know the AT protocol in order to get things done but it wouldn't hurt if you did.

# Core Methods

This atproto client includes the following methods to cover the most common operations.

## `new( ... )`

Creates a new client object.

```perl
my $bsky = At->new( service => 'https://example.com' );
```

Expected parameters include:

- `service` - required

    Host for the service.

- `language`

    Comma separated string of language codes (e.g. `en-US,en;q=0.9,fr`).

    Bluesky recommends sending the `Accept-Language` header to get posts in the user's preferred language. See
    [https://www.w3.org/International/questions/qa-lang-priorities.en](https://www.w3.org/International/questions/qa-lang-priorities.en) and
    [https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry](https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry).

## `did( )`

Gather the DID of the current user. Returns `undef` on failure or if the client is not authenticated.

```
warn $bsky->did;
```

# Session Management

You'll need an authenticated session for most API calls. There are two ways to manage sessions:

- 1. Username/password based (deprecated)
- 2. OAuth based

Developers of new code should be aware that the AT protocol will be [transitioning to OAuth in over the next year or
so (2024-2025)](https://github.com/bluesky-social/atproto/discussions/2656) and this distribution will comply with this
change.

## App password based session management

Please note that this auth method is deprecated in favor of OAuth based session management. It is recommended to use
OAuth based session management but support for this style of auth will remain as long as the Bluesky retains support
for it.

### `createAccount( ... )`

```perl
$bsky->createAccount(
    email      => 'john@example.com',
    password   => 'hunter2',
    handle     => 'john.example.com',
    inviteCode => 'aaaa-bbbb-cccc-dddd'
);
```

Create an account if supported by the service.

Expected parameters include:

- `email`
- `handle` - required

    Requested handle for the account.

- `did`

    Pre-existing atproto DID, being imported to a new account.

- `inviteCode`
- `verificationCode`
- `verificationPhone`
- `password`

    Initial account password. May need to meet instance-specific password strength requirements.

- `recoveryKey`

    DID PLC rotation key (aka, recovery key) to be included in PLC creation operation.

- `plcOp`

    A signed DID PLC operation to be submitted as part of importing an existing account to this instance.

    NOTE: this optional field may be updated when full account migration is implemented.

Account login session returned on successful account creation.

### `login( ... )`

Create an app password backed authentication session.

```perl
my $session = $bsky->login(
    identifier => 'john@example.com',
    password   => '1111-2222-3333-4444'
);
```

Expected parameters include:

- `identifier` - required

    Handle or other identifier supported by the server for the authenticating user.

- `password` - required

    This is the app password not the account's password. App passwords are generated at
    [https://bsky.app/settings/app-passwords](https://bsky.app/settings/app-passwords).

- `authFactorToken`

Returns an authorized session on success.

### `resumeSession( ... )`

Resumes an app password based session.

```perl
$bsky->resumeSession(
    accessJwt => '...',
    resumeJwt => '...'
);
```

Expected parameters include:

- `accessJwt` - required
- `refreshJwt` - required

If the `accessJwt` token has expired, we attempt to use the `refreshJwt` to continue the session with a new token. If
that also fails, well, that's kinda it.

The new session is returned on success.

## OAuth based session management

Yeah, this is on the TODO list.

# Feeds and Content Metods

Most of a core client's functionality is covered by these methods.

## `getTimeline( ... )`

Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.

```perl
my $timeline = $bsky->getTimeline( );
```

Expected parameters include:

- `algorithm`

    Variant 'algorithm' for timeline. Implementation-specific.

    NOTE: most feed flexibility has been moved to feed generator mechanism.

- `limit`

    Integer in the range of `1 .. 100`; the default is `50`.

- `cursor`

    Paginination support.

## `getAuthorFeed( ... )`

Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.

```perl
my $feed = $bsky->getAuthorFeed(
    actor  => 'did:plc:z72i7hdynmk6r22z27h6tvur',
    filter => 'posts_and_author_threads',
    limit  =>  30
);
```

Expected parameters include:

- `actor` - required

    The DID of the author whose posts you'd like to fetch.

- `limit`

    The number of posts to return per page in the range of `1 .. 100`; the default is `50`.

- `cursor`

    A cursor that tells the server where to paginate from.

- `filter`

    The type of posts you'd like to receive in the response.

    Known values:

    - `posts_with_replies` - default
    - `posts_no_replies`
    - `posts_with_media`
    - `posts_and_author_threads`

## `getPostThread( ... )`

Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed
requests.

```perl
$at->getPostThread(
    uri => 'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c'
);
```

Expected parameters include:

- `uri` - required

    Reference (AT-URI) to post record.

- `depth`

    How many levels of reply depth should be included in response between `0` and `1000`.

    Default is `6`.

- `parentHeight`

    How many levels of parent (and grandparent, etc) post to include between `0` and `1000`.

    Default is `80`.

## `getPost( ... )`

Gets a single post view for a specified AT-URI.

```perl
my $post = $at->getPost('at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c');
```

Expected parameters include:

- `uri` - required

    Reference (AT-URI) to post record.

## `getPosts( ... )`

Gets post views for a specified list of posts (by AT-URI). This is sometimes referred to as 'hydrating' a 'feed
skeleton'.

```perl
my $posts = $at->getPosts(
    uris => [
        'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c',
        'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3kvu5vjfups25',
        'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5luwyg22t'
    ]
);
```

Expected parameters include:

- `uris` - required

    List of (at most 25) post AT-URIs to return hydrated views for.

## `getLikes( ... )`

Get like records which reference a subject (by AT-URI and CID).

```perl
my $likes = $at->getLikes( uri => 'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c' );
```

Expected parameters include:

- `uri` - required

    AT-URI of the subject (eg, a post record).

- `cid`

    CID of the subject record (aka, specific version of record), to filter likes.

- `limit`

    The number of likes to return per page in the range of `1 .. 100`; the default is `50`.

- `cursor`

## `getRepostedBy( ... )`

Get a list of reposts for a given post.

```perl
my $likes = $at->getRepostedBy( uri => 'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c' );
```

Expected parameters include:

- `uri` - required

    Reference (AT-URI) of post record.

- `cid`

    If supplied, filters to reposts of specific version (by CID) of the post record.

- `limit`

    The number of reposts to return per page in the range of `1 .. 100`; the default is `50`.

- `cursor`

## `post( ... )`

Get a list of reposts for a given post.

```perl
my $post = $at->post( text => 'Pretend this is super funny.' );
```

Expected parameters include:

- `text` - required

    The primary post content. May be an empty string, if there are embeds.

- `cid`

    If supplied, filters to reposts of specific version (by CID) of the post record.

- `facets`

    Annotations of text (mentions, URLs, hashtags, etc).

- `reply`
- `embed`

    List of images, videos, etc. to display.

- `langs`

    Indicates human language of post primary text content.

- `tags`

    Additional hashtags, in addition to any included in post text and facets.

- `createdAt`

    Client-declared timestamp when this post was originally created.

    If undefined, we fill this in with `<Time::Moment->now`>.

## `deletePost( ... )`

TODO

## `like( ... )`

TODO

## `deleteLike( ... )`

TODO

## `repost( ... )`

TODO

## `deleteRepost( ... )`

TODO

## `uploadBlob( ... )`

TODO

## `( ... )`

TODO

## `( ... )`

TODO

Expected parameters include:

- `identifier`

    Handle or other identifier supported by the server for the authenticating user.

- `password`

    This is the app password not the account's password. App passwords are generated at
    [https://bsky.app/settings/app-passwords](https://bsky.app/settings/app-passwords).

## `block( ... )`

```
$bsky->block( 'sankor.bsky.social' );
```

Blocks a user.

Expected parameters include:

- `identifier` - required

    Handle or DID of the person you'd like to block.

Returns a true value on success.

## `unblock( ... )`

```
$bsky->unblock( 'sankor.bsky.social' );
```

Unblocks a user.

Expected parameters include:

- `identifier` - required

    Handle or DID of the person you'd like to block.

Returns a true value on success.

## `follow( ... )`

```
$bsky->follow( 'sankor.bsky.social' );
```

Follow a user.

Expected parameters include:

- `identifier` - required

    Handle or DID of the person you'd like to follow.

Returns a true value on success.

## `unfollow( ... )`

```
$bsky->unfollow( 'sankor.bsky.social' );
```

Unfollows a user.

Expected parameters include:

- `identifier` - required

    Handle or DID of the person you'd like to unfollow.

Returns a true value on success.

## `post( ... )`

```perl
$bsky->post( text => 'Hello, world!' );
```

Create a new post.

Expected parameters include:

- `text` - required

    Text content of the post. Must be 300 characters or fewer.

Note: This method will grow to support more features in the future.

Returns the CID and AT-URI values on success.

## `delete( ... )`

```
$bsky->delete( 'at://...' );
```

Delete a post.

Expected parameters include:

- `url` - required

    The AT-URI of the post.

Returns a true value on success.

## `profile( ... )`

```
$bsky->profile( 'sankor.bsky.social' );
```

Gathers profile data.

Expected parameters include:

- `identifier` - required

    Handle or DID of the person you'd like information on.

Returns a hash of data on success.

# Error Handling

Exception handling is carried out by returning objects with untrue boolean values.

# See Also

[App::bsky](https://metacpan.org/pod/App%3A%3Absky) - Bluesky client on the command line

# LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2\. Other copyrights, terms, and conditions may apply to data transmitted through this module.

# AUTHOR

Sanko Robinson <sanko@cpan.org>
