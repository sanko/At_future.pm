# NAME

At - The AT Protocol for Social Networking

# SYNOPSIS

```perl
use At;
my $at = At->new( host => 'https://fun.example' );
$at->server_createSession( 'sanko', '1111-aaaa-zzzz-0000' );
$at->repo_createRecord(
    repo       => $at->did,
    collection => 'app.bsky.feed.post',
    record     => { '$type' => 'app.bsky.feed.post', text => 'Hello world! I posted this via the API.', createdAt => time }
);
```

# DESCRIPTION

Bluesky is backed by the AT Protocol, a "social networking technology created to power the next generation of social
applications."

At.pm uses perl's new class system which requires perl 5.38.x or better and, like the protocol itself, is still under
development.

## At::Bluesky

At::Bluesky is a subclass with the host set to `https://bluesky.social` and all the lexicon related to the social
networking site included.

## App Passwords

Taken from the AT Protocol's official documentation:

<div>
    <blockquote>
</div>

For the security of your account, when using any third-party clients, please generate an [app
password](https://atproto.com/specs/xrpc#app-passwords) at Settings > Advanced > App passwords.

App passwords have most of the same abilities as the user's account password, but they're restricted from destructive
actions such as account deletion or account migration. They are also restricted from creating additional app passwords.

<div>
    </blockquote>
</div>

Read their disclaimer here: [https://atproto.com/community/projects#disclaimer](https://atproto.com/community/projects#disclaimer).

# Methods

The API attempts to follow the layout of the underlying protocol so changes to this module might be beyond my control.

## `new( ... )`

```perl
my $at = At->new( host => 'https://bsky.social' );
```

Creates an AT client and initiates an authentication session.

Expected parameters include:

- `host` - required

    Host for the account. If you're using the 'official' Bluesky, this would be 'https://bsky.social' but you'll probably
    want `At::Bluesky->new(...)` because that client comes with all the bits that aren't part of the core protocol.

## `resume( ... )`

```perl
my $at = At->resume( $session );
```

Resumes an authenticated session.

Expected parameters include:

- `session` - required

## `session( )`

```perl
my $restore = $at->session;
```

Returns data which may be used to resume an authenticated session.

Note that this data is subject to change in line with the AT protocol.

## `admin_deleteAccount( )`

```
$at->admin_deleteAccount( );
```

Delete a user account as an administrator.

Expected parameters include:

- `did` - required

## `admin_disableAccountInvites( )`

```
$at->admin_disableAccountInvites( );
```

Disable an account from receiving new invite codes, but does not invalidate existing codes.

Expected parameters include:

- `account` - required
- `note`

    Optional reason for disabled invites.

## `admin_disableInviteCodes( )`

```
$at->admin_disableInviteCodes( );
```

Disable some set of codes and/or all codes associated with a set of users.

Expected parameters include:

- `accounts`
- `codes`

## `admin_enableAccountInvites( )`

```
$at->admin_enableAccountInvites( );
```

Re-enable an account's ability to receive invite codes.

Expected parameters include:

- `account` - required
- `note`

    Optional reason for enabled invites.

## `admin_getAccountInfo( ... )`

```
$at->admin_getAccountInfo( ... );
```

Get details about an account.

Expected parameters include:

- `did` - required

## `admin_getAccountInfos( ... )`

```
$at->admin_getAccountInfos( ... );
```

Get details about some accounts.

Expected parameters include:

- `dids` - required

## `admin_getInviteCodes( ... )`

```
$at->admin_getInviteCodes( ... );
```

Get an admin view of invite codes.

Expected parameters include:

- `cursor`
- `limit`
- `sort`

## `admin_getSubjectStatus( ... )`

```
$at->admin_getSubjectStatus( ... );
```

Get the service-specific admin status of a subject (account, record, or blob).

Expected parameters include:

- `blob`
- `did`
- `uri`

## `admin_searchAccounts( ... )`

```
$at->admin_searchAccounts( ... );
```

Get list of accounts that matches your search query.

Expected parameters include:

- `cursor`
- `email`
- `limit`

## `admin_sendEmail( )`

```
$at->admin_sendEmail( );
```

Send email to a user's account email address.

Expected parameters include:

- `comment`

    Additional comment by the sender that won't be used in the email itself but helpful to provide more context for moderators/reviewers

- `content` - required
- `recipientDid` - required
- `senderDid` - required
- `subject`

## `admin_updateAccountEmail( )`

```
$at->admin_updateAccountEmail( );
```

Administrative action to update an account's email.

Expected parameters include:

- `account` - required

    The handle or DID of the repo.

- `email` - required

## `admin_updateAccountHandle( )`

```
$at->admin_updateAccountHandle( );
```

Administrative action to update an account's handle.

Expected parameters include:

- `did` - required
- `handle` - required

## `admin_updateAccountPassword( )`

```
$at->admin_updateAccountPassword( );
```

Update the password for a user account as an administrator.

Expected parameters include:

- `did` - required
- `password` - required

## `admin_updateSubjectStatus( )`

```
$at->admin_updateSubjectStatus( );
```

Update the service-specific admin status of a subject (account, record, or blob).

Expected parameters include:

- `deactivated`
- `subject` - required
- `takedown`

## `identity_getRecommendedDidCredentials( )`

```
$at->identity_getRecommendedDidCredentials( );
```

Describe the credentials that should be included in the DID doc of an account that is migrating to this service.

## `identity_requestPlcOperationSignature( )`

```
$at->identity_requestPlcOperationSignature( );
```

Request an email with a code to in order to request a signed PLC operation. Requires Auth.

Expected parameters include:

## `identity_resolveHandle( ... )`

```
$at->identity_resolveHandle( ... );
```

Resolves a handle (domain name) to a DID.

Expected parameters include:

- `handle` - required

    The handle to resolve.

## `identity_signPlcOperation( )`

```
$at->identity_signPlcOperation( );
```

Signs a PLC operation to update some value(s) in the requesting DID's document.

Expected parameters include:

- `alsoKnownAs`
- `rotationKeys`
- `services`
- `token`

    A token received through com.atproto.identity.requestPlcOperationSignature

- `verificationMethods`

## `identity_submitPlcOperation( )`

```
$at->identity_submitPlcOperation( );
```

Validates a PLC operation to ensure that it doesn't violate a service's constraints or get the identity into a bad state, then submits it to the PLC registry

Expected parameters include:

- `operation` - required

## `identity_updateHandle( )`

```
$at->identity_updateHandle( );
```

Updates the current account's handle. Verifies handle validity, and updates did:plc document if necessary. Implemented by PDS, and requires auth.

Expected parameters include:

- `handle` - required

    The new handle.

## `label_queryLabels( ... )`

```
$at->label_queryLabels( ... );
```

Find labels relevant to the provided AT-URI patterns. Public endpoint for moderation services, though may return different or additional results with auth.

Expected parameters include:

- `cursor`
- `limit`
- `sources`

    Optional list of label sources (DIDs) to filter on.

- `uriPatterns` - required

    List of AT URI patterns to match (boolean 'OR'). Each may be a prefix (ending with '\*'; will match inclusive of the string leading to '\*'), or a full URI.

## `moderation_createReport( )`

```
$at->moderation_createReport( );
```

Submit a moderation report regarding an atproto account or record. Implemented by moderation services (with PDS proxying), and requires auth.

Expected parameters include:

- `reason`

    Additional context about the content and violation.

- `reasonType` - required

    Indicates the broad category of violation the report is for.

- `subject` - required

## `repo_applyWrites( )`

```
$at->repo_applyWrites( );
```

Apply a batch transaction of repository creates, updates, and deletes. Requires auth, implemented by PDS.

Expected parameters include:

- `repo` - required

    The handle or DID of the repo (aka, current account).

- `swapCommit`

    If provided, the entire operation will fail if the current repo commit CID does not match this value. Used to prevent conflicting repo mutations.

- `validate`

    Can be set to 'false' to skip Lexicon schema validation of record data across all operations, 'true' to require it, or leave unset to validate only for known Lexicons.

- `writes` - required

Known errors:

- `InvalidSwap`

    Indicates that the 'swapCommit' parameter did not match current commit.

## `repo_createRecord( )`

```
$at->repo_createRecord( );
```

Create a single new repository record. Requires auth, implemented by PDS.

Expected parameters include:

- `collection` - required

    The NSID of the record collection.

- `record` - required

    The record itself. Must contain a $type field.

- `repo` - required

    The handle or DID of the repo (aka, current account).

- `rkey`

    The Record Key.

- `swapCommit`

    Compare and swap with the previous commit by CID.

- `validate`

    Can be set to 'false' to skip Lexicon schema validation of record data, 'true' to require it, or leave unset to validate only for known Lexicons.

Known errors:

- `InvalidSwap`

    Indicates that 'swapCommit' didn't match current repo commit.

## `repo_deleteRecord( )`

```
$at->repo_deleteRecord( );
```

Delete a repository record, or ensure it doesn't exist. Requires auth, implemented by PDS.

Expected parameters include:

- `collection` - required

    The NSID of the record collection.

- `repo` - required

    The handle or DID of the repo (aka, current account).

- `rkey` - required

    The Record Key.

- `swapCommit`

    Compare and swap with the previous commit by CID.

- `swapRecord`

    Compare and swap with the previous record by CID.

Known errors:

- `InvalidSwap`

## `repo_describeRepo( ... )`

```
$at->repo_describeRepo( ... );
```

Get information about an account and repository, including the list of collections. Does not require auth.

Expected parameters include:

- `repo` - required

    The handle or DID of the repo.

## `repo_getRecord( ... )`

```
$at->repo_getRecord( ... );
```

Get a single record from a repository. Does not require auth.

Expected parameters include:

- `cid`

    The CID of the version of the record. If not specified, then return the most recent version.

- `collection` - required

    The NSID of the record collection.

- `repo` - required

    The handle or DID of the repo.

- `rkey` - required

    The Record Key.

Known errors:

- `RecordNotFound`

## `repo_importRepo( )`

```
$at->repo_importRepo( );
```

Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.

Expected parameters include:

## `repo_listMissingBlobs( ... )`

```
$at->repo_listMissingBlobs( ... );
```

Returns a list of missing blobs for the requesting account. Intended to be used in the account migration flow.

Expected parameters include:

- `cursor`
- `limit`

## `repo_listRecords( ... )`

```
$at->repo_listRecords( ... );
```

List a range of records in a repository, matching a specific collection. Does not require auth.

Expected parameters include:

- `collection` - required

    The NSID of the record type.

- `cursor`
- `limit`

    The number of records to return.

- `repo` - required

    The handle or DID of the repo.

- `reverse`

    Flag to reverse the order of the returned records.

- `rkeyEnd`

    DEPRECATED: The highest sort-ordered rkey to stop at (exclusive)

- `rkeyStart`

    DEPRECATED: The lowest sort-ordered rkey to start from (exclusive)

## `repo_putRecord( )`

```
$at->repo_putRecord( );
```

Write a repository record, creating or updating it as needed. Requires auth, implemented by PDS.

Expected parameters include:

- `collection` - required

    The NSID of the record collection.

- `record` - required

    The record to write.

- `repo` - required

    The handle or DID of the repo (aka, current account).

- `rkey` - required

    The Record Key.

- `swapCommit`

    Compare and swap with the previous commit by CID.

- `swapRecord`

    Compare and swap with the previous record by CID. WARNING: nullable and optional field; may cause problems with golang implementation

- `validate`

    Can be set to 'false' to skip Lexicon schema validation of record data, 'true' to require it, or leave unset to validate only for known Lexicons.

Known errors:

- `InvalidSwap`

## `repo_uploadBlob( )`

```
$at->repo_uploadBlob( );
```

Upload a new blob, to be referenced from a repository record. The blob will be deleted if it is not referenced within a time window (eg, minutes). Blob restrictions (mimetype, size, etc) are enforced when the reference is created. Requires auth, implemented by PDS.

Expected parameters include:

## `server_activateAccount( )`

```
$at->server_activateAccount( );
```

Activates a currently deactivated account. Used to finalize account migration after the account's repo is imported and identity is setup.

Expected parameters include:

## `server_checkAccountStatus( )`

```
$at->server_checkAccountStatus( );
```

Returns the status of an account, especially as pertaining to import or recovery. Can be called many times over the course of an account migration. Requires auth and can only be called pertaining to oneself.

## `server_confirmEmail( )`

```
$at->server_confirmEmail( );
```

Confirm an email using a token from com.atproto.server.requestEmailConfirmation.

Expected parameters include:

- `email` - required
- `token` - required

Known errors:

- `AccountNotFound`
- `ExpiredToken`
- `InvalidToken`
- `InvalidEmail`

## `server_createAccount( )`

```
$at->server_createAccount( );
```

Create an account. Implemented by PDS.

Expected parameters include:

- `did`

    Pre-existing atproto DID, being imported to a new account.

- `email`
- `handle` - required

    Requested handle for the account.

- `inviteCode`
- `password`

    Initial account password. May need to meet instance-specific password strength requirements.

- `plcOp`

    A signed DID PLC operation to be submitted as part of importing an existing account to this instance. NOTE: this optional field may be updated when full account migration is implemented.

- `recoveryKey`

    DID PLC rotation key (aka, recovery key) to be included in PLC creation operation.

- `verificationCode`
- `verificationPhone`

Known errors:

- `InvalidHandle`
- `InvalidPassword`
- `InvalidInviteCode`
- `HandleNotAvailable`
- `UnsupportedDomain`
- `UnresolvableDid`
- `IncompatibleDidDoc`

## `server_createAppPassword( )`

```
$at->server_createAppPassword( );
```

Create an App Password.

Expected parameters include:

- `name` - required

    A short name for the App Password, to help distinguish them.

- `privileged`

    If an app password has 'privileged' access to possibly sensitive account state. Meant for use with trusted clients.

Known errors:

- `AccountTakedown`

## `server_createInviteCode( )`

```
$at->server_createInviteCode( );
```

Create an invite code.

Expected parameters include:

- `forAccount`
- `useCount` - required

## `server_createInviteCodes( )`

```
$at->server_createInviteCodes( );
```

Create invite codes.

Expected parameters include:

- `codeCount` - required
- `forAccounts`
- `useCount` - required

## `server_createSession( )`

```
$at->server_createSession( );
```

Create an authentication session.

Expected parameters include:

- `authFactorToken`
- `identifier` - required

    Handle or other identifier supported by the server for the authenticating user.

- `password` - required

Known errors:

- `AccountTakedown`
- `AuthFactorTokenRequired`

## `server_deactivateAccount( )`

```
$at->server_deactivateAccount( );
```

Deactivates a currently active account. Stops serving of repo, and future writes to repo until reactivated. Used to finalize account migration with the old host after the account has been activated on the new host.

Expected parameters include:

- `deleteAfter`

    A recommendation to server as to how long they should hold onto the deactivated account before deleting.

## `server_deleteAccount( )`

```
$at->server_deleteAccount( );
```

Delete an actor's account with a token and password. Can only be called after requesting a deletion token. Requires auth.

Expected parameters include:

- `did` - required
- `password` - required
- `token` - required

Known errors:

- `ExpiredToken`
- `InvalidToken`

## `server_deleteSession( )`

```
$at->server_deleteSession( );
```

Delete the current session. Requires auth.

Expected parameters include:

## `server_describeServer( )`

```
$at->server_describeServer( );
```

Describes the server's account creation requirements and capabilities. Implemented by PDS.

## `server_getAccountInviteCodes( ... )`

```
$at->server_getAccountInviteCodes( ... );
```

Get all invite codes for the current account. Requires auth.

Expected parameters include:

- `createAvailable`

    Controls whether any new 'earned' but not 'created' invites should be created.

- `includeUsed`

Known errors:

- `DuplicateCreate`

## `server_getServiceAuth( ... )`

```
$at->server_getServiceAuth( ... );
```

Get a signed token on behalf of the requesting DID for the requested service.

Expected parameters include:

- `aud` - required

    The DID of the service that the token will be used to authenticate with

- `exp`

    The time in Unix Epoch seconds that the JWT expires. Defaults to 60 seconds in the future. The service may enforce certain time bounds on tokens depending on the requested scope.

- `lxm`

    Lexicon (XRPC) method to bind the requested token to

Known errors:

- `BadExpiration`

    Indicates that the requested expiration date is not a valid. May be in the past or may be reliant on the requested scopes.

## `server_getSession( )`

```
$at->server_getSession( );
```

Get information about the current auth session. Requires auth.

## `server_listAppPasswords( )`

```
$at->server_listAppPasswords( );
```

List all App Passwords.

Known errors:

- `AccountTakedown`

## `server_refreshSession( )`

```
$at->server_refreshSession( );
```

Refresh an authentication session. Requires auth using the 'refreshJwt' (not the 'accessJwt').

Expected parameters include:

Known errors:

- `AccountTakedown`

## `server_requestAccountDelete( )`

```
$at->server_requestAccountDelete( );
```

Initiate a user account deletion via email.

Expected parameters include:

## `server_requestEmailConfirmation( )`

```
$at->server_requestEmailConfirmation( );
```

Request an email with a code to confirm ownership of email.

Expected parameters include:

## `server_requestEmailUpdate( )`

```
$at->server_requestEmailUpdate( );
```

Request a token in order to update email.

Expected parameters include:

## `server_requestPasswordReset( )`

```
$at->server_requestPasswordReset( );
```

Initiate a user account password reset via email.

Expected parameters include:

- `email` - required

## `server_reserveSigningKey( )`

```
$at->server_reserveSigningKey( );
```

Reserve a repo signing key, for use with account creation. Necessary so that a DID PLC update operation can be constructed during an account migraiton. Public and does not require auth; implemented by PDS. NOTE: this endpoint may change when full account migration is implemented.

Expected parameters include:

- `did`

    The DID to reserve a key for.

## `server_resetPassword( )`

```
$at->server_resetPassword( );
```

Reset a user account password using a token.

Expected parameters include:

- `password` - required
- `token` - required

Known errors:

- `ExpiredToken`
- `InvalidToken`

## `server_revokeAppPassword( )`

```
$at->server_revokeAppPassword( );
```

Revoke an App Password by name.

Expected parameters include:

- `name` - required

## `server_updateEmail( )`

```
$at->server_updateEmail( );
```

Update an account's email.

Expected parameters include:

- `email` - required
- `emailAuthFactor`
- `token`

    Requires a token from com.atproto.sever.requestEmailUpdate if the account's email has been confirmed.

Known errors:

- `ExpiredToken`
- `InvalidToken`
- `TokenRequired`

## `sync_getBlob( ... )`

```
$at->sync_getBlob( ... );
```

Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.

Expected parameters include:

- `cid` - required

    The CID of the blob to fetch

- `did` - required

    The DID of the account.

Known errors:

- `BlobNotFound`
- `RepoNotFound`
- `RepoTakendown`
- `RepoSuspended`
- `RepoDeactivated`

## `sync_getBlocks( ... )`

```
$at->sync_getBlocks( ... );
```

Get data blocks from a given repo, by CID. For example, intermediate MST nodes, or records. Does not require auth; implemented by PDS.

Expected parameters include:

- `cids` - required
- `did` - required

    The DID of the repo.

Known errors:

- `BlockNotFound`
- `RepoNotFound`
- `RepoTakendown`
- `RepoSuspended`
- `RepoDeactivated`

## `sync_getCheckout( ... )`

```
$at->sync_getCheckout( ... );
```

DEPRECATED - please use com.atproto.sync.getRepo instead

Expected parameters include:

- `did` - required

    The DID of the repo.

## `sync_getHead( ... )`

```
$at->sync_getHead( ... );
```

DEPRECATED - please use com.atproto.sync.getLatestCommit instead

Expected parameters include:

- `did` - required

    The DID of the repo.

Known errors:

- `HeadNotFound`

## `sync_getLatestCommit( ... )`

```
$at->sync_getLatestCommit( ... );
```

Get the current commit CID & revision of the specified repo. Does not require auth.

Expected parameters include:

- `did` - required

    The DID of the repo.

Known errors:

- `RepoNotFound`
- `RepoTakendown`
- `RepoSuspended`
- `RepoDeactivated`

## `sync_getRecord( ... )`

```
$at->sync_getRecord( ... );
```

Get data blocks needed to prove the existence or non-existence of record in the current version of repo. Does not require auth.

Expected parameters include:

- `collection` - required
- `commit`

    DEPRECATED: referenced a repo commit by CID, and retrieved record as of that commit

- `did` - required

    The DID of the repo.

- `rkey` - required

    Record Key

Known errors:

- `RecordNotFound`
- `RepoNotFound`
- `RepoTakendown`
- `RepoSuspended`
- `RepoDeactivated`

## `sync_getRepo( ... )`

```
$at->sync_getRepo( ... );
```

Download a repository export as CAR file. Optionally only a 'diff' since a previous revision. Does not require auth; implemented by PDS.

Expected parameters include:

- `did` - required

    The DID of the repo.

- `since`

    The revision ('rev') of the repo to create a diff from.

Known errors:

- `RepoNotFound`
- `RepoTakendown`
- `RepoSuspended`
- `RepoDeactivated`

## `sync_getRepoStatus( ... )`

```
$at->sync_getRepoStatus( ... );
```

Get the hosting status for a repository, on this server. Expected to be implemented by PDS and Relay.

Expected parameters include:

- `did` - required

    The DID of the repo.

Known errors:

- `RepoNotFound`

## `sync_listBlobs( ... )`

```
$at->sync_listBlobs( ... );
```

List blob CIDs for an account, since some repo revision. Does not require auth; implemented by PDS.

Expected parameters include:

- `cursor`
- `did` - required

    The DID of the repo.

- `limit`
- `since`

    Optional revision of the repo to list blobs since.

Known errors:

- `RepoNotFound`
- `RepoTakendown`
- `RepoSuspended`
- `RepoDeactivated`

## `sync_listRepos( ... )`

```
$at->sync_listRepos( ... );
```

Enumerates all the DID, rev, and commit CID for all repos hosted by this service. Does not require auth; implemented by PDS and Relay.

Expected parameters include:

- `cursor`
- `limit`

## `sync_notifyOfUpdate( )`

```
$at->sync_notifyOfUpdate( );
```

Notify a crawling service of a recent update, and that crawling should resume. Intended use is after a gap between repo stream events caused the crawling service to disconnect. Does not require auth; implemented by Relay.

Expected parameters include:

- `hostname` - required

    Hostname of the current service (usually a PDS) that is notifying of update.

## `sync_requestCrawl( )`

```
$at->sync_requestCrawl( );
```

Request a service to persistently crawl hosted repos. Expected use is new PDS instances declaring their existence to Relays. Does not require auth.

Expected parameters include:

- `hostname` - required

    Hostname of the current service (eg, PDS) that is requesting to be crawled.

## `temp_checkSignupQueue( )`

```
$at->temp_checkSignupQueue( );
```

Check accounts location in signup queue.

## `temp_fetchLabels( ... )`

```
$at->temp_fetchLabels( ... );
```

DEPRECATED: use queryLabels or subscribeLabels instead -- Fetch all labels from a labeler created after a certain date.

Expected parameters include:

- `limit`
- `since`

## `temp_requestPhoneVerification( )`

```
$at->temp_requestPhoneVerification( );
```

Request a verification code to be sent to the supplied phone number

Expected parameters include:

- `phoneNumber` - required

# See Also

[App::bsky](https://metacpan.org/pod/App%3A%3Absky) - Bluesky client on the command line

[https://atproto.com/](https://atproto.com/)

[https://bsky.app/profile/atperl.bsky.social](https://bsky.app/profile/atperl.bsky.social)

[Bluesky on Wikipedia.org](https://en.wikipedia.org/wiki/Bluesky_\(social_network\))

# LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2\. Other copyrights, terms, and conditions may apply to data transmitted through this module.

# AUTHOR

Sanko Robinson <sanko@cpan.org>
