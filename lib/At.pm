package At 1.0 {
    use v5.38;
    use warnings::register;
    use experimental qw[try for_list];
    no warnings qw[experimental::builtin experimental::try];
    use parent               qw[Exporter];
    use Carp                 qw[carp confess];
    use File::ShareDir::Tiny qw[dist_dir module_dir];
    use JSON::Tiny           qw[decode_json];
    use Path::Tiny           qw[path];
    use Time::Moment;    # Internal; standardize around Zulu
    use URI;
    #
    use At::Error;
    use At::Protocol::DID;
    use At::Protocol::Handle;
    use At::Protocol::NSID;
    use At::Protocol::URI;
    #
    use Data::Dump;
    #
    $|++;
    #
    sub _percent ( $limit, $remaining ) { $remaining && $limit ? ( ( $limit / $remaining ) * 100 ) : 0 }
    sub _plural( $count, $word ) { $count ? sprintf '%d %s%s', $count, $word, $count == 1 ? '' : 's' : () }

    sub _duration ($seconds) {
        $seconds || return '0 seconds';
        $seconds = abs $seconds;                                                                        # just in case
        my ( $time, @times ) = reverse grep {defined} _plural( int( $seconds / 31536000 ), 'year' ),    # assume 365 days and no leap seconds
            _plural( int( ( $seconds % 31536000 ) / 604800 ), 'week' ), _plural( int( ( $seconds % 604800 ) / 86400 ), 'day' ),
            _plural( int( ( $seconds % 86400 ) / 3600 ),      'hour' ), _plural( int( ( $seconds % 3600 ) / 60 ),      'minute' ),
            _plural( $seconds % 60,                           'second' );
        join ' and ', @times ? join( ', ', reverse @times ) : (), $time;
    }
    #
    sub new ( $class, %args ) {
        $args{service} // Carp::croak 'At requires a service';
        $args{service} = URI->new( $args{service} ) unless builtin::blessed $args{service};
        $args{http} //= Mojo::UserAgent->can('start') ? At::UserAgent::Mojo->new(%args) : sub {
            require At::UserAgent::Tiny;
            At::UserAgent::Tiny->new(%args);
            }
            ->();
        bless {
            http       => $args{http},
            service    => $args{service},
            ratelimits => {                 # https://docs.bsky.app/docs/advanced-guides/rate-limits
                global        => {},
                updateHandle  => {},    # per DID
                updateHandle  => {},    # per DID
                createSession => {},    # per handle
                deleteAccount => {},    # by IP
                resetPassword => {}     # by IP
            }
        }, $class;
    }

    sub ratelimit_ ( $s, $rate, $type, $meta //= () ) {    #~ https://docs.bsky.app/docs/advanced-guides/rate-limits
        defined $meta ? $s->{ratelimits}{$type}{$meta} = $rate : $s->{ratelimits}{$type} = $rate;
    }

    sub _ratecheck( $s, $type, $meta //= () ) {
        my $rate = defined $meta ? $s->{ratelimits}{$type}{$meta} : $s->{ratelimits}{$type};
        $rate->{reset} // return;
        return warnings::warnif( At => sprintf 'Exceeded %s rate limit. Try again in %s', $type, _duration( $rate->{reset} - time ) )
            if defined $rate->{reset} && $rate->{remaining} == 0 && $rate->{reset} > time;
        my $percent = _percent( $rate->{remaining}, $rate->{limit} );
        warnings::warnif(
            At => sprintf '%.2f%% of %s rate limit remaining (%d of %d). Slow down or try again in %s',
            $percent, $type, $rate->{remaining}, $rate->{limit}, _duration( $rate->{reset} - time )
        ) if $percent <= 5;
    }

    sub did ($s) {
        my $session = $s->session;
        defined $session ? $session->{did} : ();
    }

    sub _decode_token ($token) {
        use MIME::Base64 qw[decode_base64];
        use JSON::Tiny   qw[decode_json];
        my ( $header, $payload, $sig ) = split /\./, $token;
        $payload =~ tr[-_][+/];    # Replace Base64-URL characters with standard Base64
        decode_json decode_base64 $payload;
    }
    sub session($s) { $s->{http}->session }

    sub resumeSession( $s, %args ) {
        my $access  = _decode_token $args{accessJwt};
        my $refresh = _decode_token $args{refreshJwt};
        if ( time > $access->{exp} && time < $refresh->{exp} ) {
            my ( $session, $headers ) = At::com::atproto::server::refreshSession( $s, headers => { Authorization => 'Bearer ' . $args{refreshJwt} } );
            $s->{http}->_set_session($session);
            return $session;
        }
        my ( $session, $headers ) = At::com::atproto::server::getSession( $s, headers => { Authorization => 'Bearer ' . $args{accessJwt} } );
        if ($session) {
            $session->{accessJwt}  = $args{accessJwt};
            $session->{refreshJwt} = $args{refreshJwt};
            $s->{http}->_set_session($session);
        }
        $session;
    }
    #
    sub createAccount ( $s, %args ) {
        my $session = At::com::atproto::server::createAccount( $s, content => \%args );
        $s->{http}->_set_session($session) if $session;
        $session;
    }

    sub login ( $s, %args ) {
        my ( $session, $headers ) = At::com::atproto::server::createSession( $s, content => \%args );
        $session || return $session;
        $s->{http}->_set_session($session);
        $session;
    }

    sub getTimeline ( $s, %args ) {
        At::app::bsky::feed::getTimeline( $s, content => \%args );
    }

    sub getAuthorFeed ( $s, %args ) {
        At::app::bsky::feed::getAuthorFeed( $s, content => \%args );
    }

    sub getPostThread ( $s, %args ) {
        At::app::bsky::feed::getPostThread( $s, content => \%args );
    }

    sub getPost ( $s, $uri ) {
        At::app::bsky::feed::getPosts( $s, content => { uris => [$uri] } );
    }

    sub getPosts ( $s, %args ) {
        At::app::bsky::feed::getPosts( $s, content => \%args );
    }

    sub getLikes ( $s, %args ) {
        At::app::bsky::feed::getLikes( $s, content => \%args );
    }

    sub getRepostedBy ( $s, %args ) {
        At::app::bsky::feed::getRepostedBy( $s, content => \%args );
    }

    sub post ( $s, %args ) {
        At::com::atproto::repo::createRecord(
            $s,
            content => {
                repo       => $s->did,
                collection => 'app.bsky.feed.post',
                record     => { '$type' => 'app.bsky.feed.post', createdAt => Time::Moment->now->to_string, %args }
            }
        );
    }

    sub deletePost ( $s, $at_uri ) {
        $at_uri = At::Protocol::URI->new($at_uri) unless builtin::blessed $at_uri;
        At::com::atproto::repo::deleteRecord( $s, content => { repo => $s->did, collection => 'app.bsky.feed.post', rkey => $at_uri->rkey } );
    }

    sub like ( $s, $at_uri, $cid ) {
        $at_uri = At::Protocol::URI->new($at_uri) unless builtin::blessed $at_uri;
        At::com::atproto::repo::createRecord(
            $s,
            content => {
                repo       => $s->did,
                collection => 'app.bsky.feed.like',
                record     => {
                    '$type' => 'app.bsky.feed.like',
                    subject => {                       # com.atproto.repo.strongRef
                        uri => $at_uri,
                        cid => $cid
                    },
                    createdAt => Time::Moment->now->to_string
                }
            }
        );
    }

    sub deleteLike ( $s, $at_uri ) {
        $at_uri = At::Protocol::URI->new($at_uri) unless builtin::blessed $at_uri;
        At::com::atproto::repo::deleteRecord( $s, content => { repo => $s->did, collection => 'app.bsky.feed.like', rkey => $at_uri->rkey } );
    }

    sub repost ( $s, $at_uri, $cid ) {
        $at_uri = At::Protocol::URI->new($at_uri) unless builtin::blessed $at_uri;
        At::com::atproto::repo::createRecord(
            $s,
            content => {
                repo       => $s->did,
                collection => 'app.bsky.feed.repost',
                record     => {
                    '$type' => 'app.bsky.feed.repost',
                    subject => {                         # com.atproto.repo.strongRef
                        uri => $at_uri,
                        cid => $cid
                    },
                    createdAt => Time::Moment->now->to_string
                }
            }
        );
    }

    sub deleteRepost ( $s, $at_uri ) {
        $at_uri = At::Protocol::URI->new($at_uri) unless builtin::blessed $at_uri;
        At::com::atproto::repo::deleteRecord( $s, content => { repo => $s->did, collection => 'app.bsky.feed.repost', rkey => $at_uri->rkey } );
    }

    sub uploadBlob ( $s, $data, $type //= () ) {
        At::com::atproto::repo::uploadBlob( $s, content => $data, defined $type ? ( headers => +{ 'Content-type' => $type } ) : () );
    }

    #  Social graph
    sub getFollows ( $s, $actor, $type //= (), $cursor //= () ) {
        At::app::bsky::graph::getFollows( $s,
            content => { actor => $actor, defined $type ? ( type => $type ) : (), defined $cursor ? ( cursor => $cursor ) : () } );
    }

    sub getFollowers ( $s, $actor, $type //= (), $cursor //= () ) {
        At::app::bsky::graph::getFollowers( $s,
            content => { actor => $actor, defined $type ? ( type => $type ) : (), defined $cursor ? ( cursor => $cursor ) : () } );
    }

    sub follow ( $s, $did ) {
        At::com::atproto::repo::createRecord(
            $s,
            content => {
                repo       => $s->did,
                collection => 'app.bsky.graph.follow',
                record     => { '$type' => 'app.bsky.graph.follow', subject => $did, createdAt => Time::Moment->now->to_string }
            }
        );
    }

    sub deleteFollow ( $s, $at_uri ) {
        $at_uri = At::Protocol::URI->new($at_uri) unless builtin::blessed $at_uri;
        At::com::atproto::repo::deleteRecord( $s, content => { repo => $s->did, collection => 'app.bsky.graph.follow', rkey => $at_uri->rkey } );
    }

    # Actors
    sub getProfile ( $s, %args ) {
        At::app::bsky::actor::getProfile( $s, content => \%args );
    }

    sub upsertProfile ( $s, $fn ) {
        my $repo = $s->did;
        my $existing;
        for ( 0 .. 5 ) {    # Might take a few tries
            $existing
                ||= At::com::atproto::repo::getRecord( $s, content => { repo => $repo, collection => 'app.bsky.actor.profile', rkey => 'self' } );

            #~ throw $existing unless $existing;
            my %updated = $fn->( %{$existing} );
            my $okay    = At::com::atproto::repo::putRecord(
                $s,
                content => {
                    repo       => $repo,
                    collection => 'app.bsky.actor.profile',
                    rkey       => 'self',
                    record     => { %updated, type => 'app.bsky.actor.profile' },
                    swapRecord => $existing ? $existing->{cid} : undef
                }
            );
            return $okay if $okay;
        }
        ();
    }

    #~ await agent.getProfiles(params, opts)
    #~ await agent.getSuggestions(params, opts)
    #~ await agent.searchActors(params, opts)
    #~ await agent.searchActorsTypeahead(params, opts)
    #~ await agent.mute(did)
    #~ await agent.unmute(did)
    #~ await agent.muteModList(listUri)
    #~ await agent.unmuteModList(listUri)
    #~ await agent.blockModList(listUri)
    #~ await agent.unblockModList(listUri)
    #~  Notifications
    #~ await agent.listNotifications(params, opts)
    #~ await agent.countUnreadNotifications(params, opts)
    #~ await agent.updateSeenNotifications()
    #~  Identity
    #~ await agent.resolveHandle(params, opts)
    #~ await agent.updateHandle(params, opts)
    #
    {
        our %capture;

        sub _set_capture ( $namespace, $schema ) {
            my @path_components = split( /\./, $namespace );
            my $current_ref     = \%capture;
            $current_ref = $current_ref->{$_} //= {} for @path_components[ 0 .. $#path_components - 1 ];
            $current_ref->{ $path_components[-1] } = $schema;
            {
                no strict 'refs';
                *{ _namespace2package($namespace) . '::new' } = sub ( $class, %args ) {

                    # Only verify if fields are missing
                    my @missing = sort grep { !defined $args{$_} } @{ $schema->{required} };
                    Carp::croak sprintf 'missing required field%s in %s->new(...): %s', ( scalar @missing == 1 ? '' : 's' ), $class, join ', ',
                        @missing
                        if @missing;
                    bless \%args, $class;
                };
                for my $property ( keys %{ $schema->{properties} } ) {
                    *{ _namespace2package($namespace) . '::' . $property } = sub ( $s, $new //= () ) {
                        $s->{$property} = $new if defined $new;
                        $s->{$property};
                    }
                }
                *{ _namespace2package($namespace) . '::_schema' } = sub ($s) {
                    $schema;
                };
                *{ _namespace2package($namespace) . '::_namespace' } = sub ($s) {
                    $namespace;
                };
                *{ _namespace2package($namespace) . '::verify' } = sub ($s) {

                    # TODO: verify that data fills schema requirements
                    #~ ddx $schema;
                    #~ ddx $s;
                    for my $property ( keys %{ $schema->{properties} } ) {

                        #~ ddx $property;
                        #~ ddx $schema->{properties}{$property};
                    }
                    return 0;    # This doesn't work yet.

                    #~ exit;
                };
            }
        }

        sub _get_capture ($namespace) {
            my @path_elements = split( /\./, $namespace );
            my $current_ref   = \%capture;
            for my $element (@path_elements) {
                return undef unless exists $current_ref->{$element};
                $current_ref = $current_ref->{$element};
            }
            $current_ref;
        }
    }

    sub _namespace ( $l, $r ) {
        return $r      if $r =~ m[.+#];
        return $` . $r if $l =~ m[#.+];
        $l . $r;
    }

    # Init
    sub import ( $class, %imports ) {
        my $lexicon;    # Allow user to define where lexicon snapshots are to be found
        try {
            $lexicon = delete $imports{'-lexicons'} // dist_dir(__PACKAGE__);
        }
        catch ($error) {
            $lexicon = './share'
        }
        finally {
            $lexicon = path($lexicon) unless builtin::blessed $lexicon;
            $lexicon = $lexicon->child('lexicons')->realpath
        }
        #
        my $iter = $lexicon->iterator( { recurse => 1 } );
        while ( my $next = $iter->() ) {
            if ( $next->is_file ) {
                my $raw = decode_json $next->slurp_utf8;
                for my ( $name, $schema )( %{ $raw->{defs} } ) {
                    my $fqdn = $raw->{id} . ( $name eq 'main' ? '' : '#' . $name );    # RDN
                    if ( $schema->{type} eq 'array' ) {
                        _set_capture( $fqdn, $schema );
                    }
                    elsif ( $schema->{type} eq 'object' ) {
                        _set_capture( $fqdn, $schema );
                    }
                    elsif ( $schema->{type} eq 'procedure' ) {
                        my @namespace = split /\./, $fqdn;
                        no strict 'refs';
                        register( $_->{name}, $_->{description} // '' ) for grep { !__PACKAGE__->can( $_->{name} ) } @{ $schema->{errors} };
                        my $rate_category
                            = $namespace[-1] =~ m[^(updateHandle|createAccount|createSession|deleteAccount|resetPassword)$] ? $namespace[-1] :
                            'global';
                        *{ join '::', 'At', @namespace } = sub ( $s, %args ) {
                            my $_rate_meta
                                = $rate_category eq 'createSession' ? $args{identifier} : $rate_category eq 'updateHandle' ? $args{did} : ();
                            $s->_ratecheck( $rate_category, $_rate_meta );
                            my ( $content, $headers )
                                = $s->{http}->post( $s->{service} . ( '/xrpc/' . $fqdn ), { content => delete $args{content}, %args } );

                            #~ https://docs.bsky.app/docs/advanced-guides/rate-limits
                            $s->ratelimit_( { map { $_ => $headers->{ 'ratelimit-' . $_ } } qw[limit remaining reset] }, $rate_category,
                                $_rate_meta );
                            $s->_ratecheck( $rate_category, $_rate_meta );
                            $content = builtin::blessed $content? $content : _coerce( $fqdn, $schema->{output}{schema}, $content );
                            wantarray ? ( $content, $headers ) : $content;
                        };
                        _set_capture( $fqdn, $schema->{output}{schema} );
                    }
                    elsif ( $schema->{type} eq 'query' ) {
                        my @namespace = split /\./, $fqdn;
                        no strict 'refs';
                        register( $_->{name}, $_->{description} // '' ) for grep { !__PACKAGE__->can( $_->{name} ) } @{ $schema->{errors} };
                        *{ join '::', 'At', @namespace } = sub ( $s, %args ) {
                            $s->_ratecheck('global');

                            # ddx $schema;
                            my ( $content, $headers )
                                = $s->{http}->get( $s->{service} . ( '/xrpc/' . $fqdn ), { content => delete $args{content}, %args } );

                            #~ https://docs.bsky.app/docs/advanced-guides/rate-limits
                            $s->ratelimit_( { map { $_ => $headers->{ 'ratelimit-' . $_ } } qw[limit remaining reset] }, 'global' );
                            $s->_ratecheck('global');
                            $content = builtin::blessed $content? $content : _coerce( $fqdn, $schema->{output}{schema}, $content );
                            wantarray ? ( $content, $headers ) : $content;
                        };
                        _set_capture( $fqdn, $schema->{output}{schema} );
                    }
                    elsif ( $schema->{type} eq 'record' ) {
                        _set_capture( join( '.', $raw->{id}, ( $name eq 'main' ? () : $name ) ), $schema );
                    }
                    elsif ( $schema->{type} eq 'string' )       { _set_capture( $fqdn, $schema ); }
                    elsif ( $schema->{type} eq 'subscription' ) { use Data::Dump; ddx $schema; }
                    elsif ( $schema->{type} eq 'token' ) {    # Generally just a string
                        my $namespace = $fqdn =~ s[[#\.]][::]gr;
                        my $package   = _namespace2package($fqdn);
                        no strict 'refs';

                        #~ *{ $package . "::(\"\"" } = sub ( $s, $u, $q ) { $fqdn };
                        #~ *{ $package . "::((" }  = sub {$fqdn};
                        *{$package} = sub ( ) { $fqdn; };
                    }
                    else {
                        ...;
                    }
                }

                # $lexicon{ $raw->{id} } = $raw;
            }
        }
    }

    sub _namespace2package ($fqdn) {
        my $namespace = $fqdn =~ s[[#\.]][::]gr;
        'At::Lexicon::' . $namespace;
    }
    my %coercions = (
        array => sub ( $namespace, $schema, $data ) {
            [ map { _coerce( $namespace, $schema->{items}, $_ ) } @$data ]
        },
        boolean => sub ( $namespace, $schema, $data ) { !!$data },
        bytes   => sub ( $namespace, $schema, $data ) {$data},
        blob    => sub ( $namespace, $schema, $data ) {$data},
        integer => sub ( $namespace, $schema, $data ) { int $data },
        object  => sub ( $namespace, $schema, $data ) {

            # TODO: warn about missing properties first
            for my ( $name, $subschema )( %{ $schema->{properties} } ) {
                $data->{$name} = _coerce( $namespace, $subschema, $data->{$name} );
            }
            _namespace2package($namespace)->new(%$data);
        },
        ref => sub ( $namespace, $schema, $data ) {
            $namespace = _namespace( $namespace, $schema->{ref} );
            my $ref_schema = _get_capture($namespace);
            $ref_schema // Carp::carp( 'Unknown type: ' . $namespace ) && return $data;
            _coerce( $namespace, $ref_schema, $data );
        },
        union => sub ( $namespace, $schema, $data ) {
            my @namespaces = map { _namespace( $namespace, $_ ) } @{ $schema->{refs} };
            Carp::cluck 'Incorrect union type: ' . $data->{'$type'} unless grep { $data->{'$type'} eq $_ } @namespaces;
            bless _coerce( $data->{'$type'}, _get_capture( $data->{'$type'} ), $data ), _namespace2package( $data->{'$type'} );
        },
        unknown => sub ( $namespace, $schema, $data ) {$data},
        string  => sub ( $namespace, $schema, $data ) {
            $data // return ();
            if ( defined $schema->{format} ) {
                if    ( $schema->{format} eq 'uri' )    { return URI->new($data); }
                elsif ( $schema->{format} eq 'at-uri' ) { return At::Protocol::URI->new($data); }
                elsif ( $schema->{format} eq 'cid' )    { return $data; }                           # TODO
                elsif ( $schema->{format} eq 'datetime' ) {
                    return $data =~ /\D/ ? Time::Moment->from_string($data) : Time::Moment->from_epoch($data);
                }
                elsif ( $schema->{format} eq 'did' ) {
                    return At::Protocol::DID->new($data);
                }
                elsif ( $schema->{format} eq 'handle' ) {
                    return At::Protocol::Handle->new($data);
                }
                warn $data;
                ddx $schema;
                ...;
            }
            $data;
        }
    );

    sub _coerce ( $namespace, $schema, $data ) {
        $data // return ();
        return $coercions{ $schema->{type} }->( $namespace, $schema, $data ) if defined $coercions{ $schema->{type} };
        use Data::Dump;
        ddx $schema;
        die 'Unknown coercion: ' . $schema->{type};
    }
}
1;
__END__
# https://github.com/bluesky-social/atproto/tree/main/packages/api
# https://docs.bsky.app/docs/tutorials/viewing-feeds
=encoding utf-8

=head1 NAME

At - The AT Protocol for Social Networking

=head1 SYNOPSIS

    use At;
    my $bsky = At->new( service => 'https://bsky.social' );
    # To be continued...

=head1 DESCRIPTION

You shouldn't need to know the AT protocol in order to get things done but it wouldn't hurt if you did.

=head1 Core Methods

This atproto client includes the following methods to cover the most common operations.

=head2 C<new( ... )>

Creates a new client object.

    my $bsky = At->new( service => 'https://example.com' );

Expected parameters include:

=over

=item C<service> - required

Host for the service.

=item C<language>

Comma separated string of language codes (e.g. C<en-US,en;q=0.9,fr>).

Bluesky recommends sending the C<Accept-Language> header to get posts in the user's preferred language. See
L<https://www.w3.org/International/questions/qa-lang-priorities.en> and
L<https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry>.

=back

=head2 C<did( )>

Gather the DID of the current user. Returns C<undef> if the client is not authenticated.

    warn $bsky->did;

=head1 Session Management

You'll need an authenticated session for most API calls.

There are two ways to manage sessions:

=over

=item 1. Username/password based (deprecated)

=item 2. OAuth based

=back

Developers of new code should be aware that the AT protocol will be L<transitioning to OAuth in over the next year or
so (2024-2025)|https://github.com/bluesky-social/atproto/discussions/2656>.

=head2 App password based session management

Please note that this auth method is deprecated in favor of OAuth based session management. It is recommended to use
OAuth based session management.

=head3 C<createAccount( ... )>

Create an account.

    $bsky->createAccount(
        email      => 'john@example.com',
        password   => 'hunter2',
        handle     => 'john.example.com',
        inviteCode => 'aaaa-bbbb-cccc-dddd'
    );

Expected parameters include:

=over

=item C<email>

=item C<handle> - required

Requested handle for the account.

=item C<did>

Pre-existing atproto DID, being imported to a new account.

=item C<inviteCode>

=item C<verificationCode>

=item C<verificationPhone>

=item C<password>

Initial account password. May need to meet instance-specific password strength requirements.

=item C<recoveryKey>

DID PLC rotation key (aka, recovery key) to be included in PLC creation operation.

=item C<plcOp>

A signed DID PLC operation to be submitted as part of importing an existing account to this instance.

NOTE: this optional field may be updated when full account migration is implemented.

=back

Account login session returned on successful account creation.

=head3 C<login( ... )>

Create an authentication session.

    my $session = $bsky->login(
        identifier => 'john@example.com',
        password   => '1111-2222-3333-4444'
    );

Expected parameters include:

=over

=item C<identifier> - required

Handle or other identifier supported by the server for the authenticating user.

=item C<password> - required

This is the app password not the account's password. App passwords are generated at
L<https://bsky.app/settings/app-passwords>.

=item C<authFactorToken>

=back

Returns an authorized session on success.

=head3 C<resumeSession( ... )>

Resumes an app password based session.

    $bsky->resumeSession( $savedSession );

Expected parameters include:

=over

=item C<session>

=back

=head2 OAuth based session management

Yeah, this is on the TODO list.

=head1 Feeds and Content

Most of a core client's functionality is covered by these methods.

=head2 C<getTimeline( ... )>

Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.

    my $timeline = $bsky->getTimeline( );

Expected parameters include:

=over

=item C<algorithm>

Variant 'algorithm' for timeline. Implementation-specific.

NOTE: most feed flexibility has been moved to feed generator mechanism.

=item C<limit>

Integer in the range of C<1 .. 100>; the default is C<50>.

=item C<cursor>

=back

=head2 C<getAuthorFeed( ... )>

Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.

    my $feed = $bsky->getAuthorFeed(
        actor  => 'did:plc:z72i7hdynmk6r22z27h6tvur',
        filter => 'posts_and_author_threads',
        limit  =>  30
    );

Expected parameters include:

=over

=item C<actor> - required

The DID of the author whose posts you'd like to fetch.

=item C<limit>

The number of posts to return per page in the range of C<1 .. 100>; the default is C<50>.

=item C<cursor>

A cursor that tells the server where to paginate from.

=item C<filter>

The type of posts you'd like to receive in the response.

Known values:

=over

=item C<posts_with_replies> - default

=item C<posts_no_replies>

=item C<posts_with_media>

=item C<posts_and_author_threads>

=back

=back

=head2 C<getPostThread( ... )>

Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed
requests.

    $at->getPostThread(
        uri => 'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c'
    );

Expected parameters include:

=over

=item C<uri> - required

Reference (AT-URI) to post record.

=item C<depth>

How many levels of reply depth should be included in response between C<0> and C<1000>.

Default is C<6>.

=item C<parentHeight>

How many levels of parent (and grandparent, etc) post to include between C<0> and C<1000>.

Default is C<80>.

=back

=head2 C<getPost( ... )>

Gets a single post view for a specified AT-URI.

    my $post = $at->getPost('at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c');

Expected parameters include:

=over

=item C<uri> - required

Reference (AT-URI) to post record.

=back

=head2 C<getPosts( ... )>

Gets post views for a specified list of posts (by AT-URI). This is sometimes referred to as 'hydrating' a 'feed
skeleton'.

    my $posts = $at->getPosts(
        uris => [
            'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c',
            'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3kvu5vjfups25',
            'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5luwyg22t'
        ]
    );

Expected parameters include:

=over

=item C<uris> - required

List of (at most 25) post AT-URIs to return hydrated views for.

=back

=head2 C<getLikes( ... )>

Get like records which reference a subject (by AT-URI and CID).

    my $likes = $at->getLikes( uri => 'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c' );

Expected parameters include:

=over

=item C<uri> - required

AT-URI of the subject (eg, a post record).

=item C<cid>

CID of the subject record (aka, specific version of record), to filter likes.

=item C<limit>

The number of likes to return per page in the range of C<1 .. 100>; the default is C<50>.

=item C<cursor>

=back

=head2 C<getRepostedBy( ... )>

Get a list of reposts for a given post.

    my $likes = $at->getRepostedBy( uri => 'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c' );

Expected parameters include:

=over

=item C<uri> - required

Reference (AT-URI) of post record.

=item C<cid>

If supplied, filters to reposts of specific version (by CID) of the post record.

=item C<limit>

The number of reposts to return per page in the range of C<1 .. 100>; the default is C<50>.

=item C<cursor>

=back

=head2 C<post( ... )>

TODO

=head2 C<deletePost( ... )>

TODO

=head2 C<like( ... )>

TODO

=head2 C<deleteLike( ... )>

TODO

=head2 C<repost( ... )>

TODO

=head2 C<deleteRepost( ... )>

TODO

=head2 C<uploadBlob( ... )>

TODO

=head2 C<( ... )>

TODO

=head2 C<( ... )>

TODO

Expected parameters include:

=over

=item C<identifier>

Handle or other identifier supported by the server for the authenticating user.

=item C<password>

This is the app password not the account's password. App passwords are generated at
L<https://bsky.app/settings/app-passwords>.

=back

=head2 C<block( ... )>

    $bsky->block( 'sankor.bsky.social' );

Blocks a user.

Expected parameters include:

=over

=item C<identifier> - required

Handle or DID of the person you'd like to block.

=back

Returns a true value on success.

=head2 C<unblock( ... )>

    $bsky->unblock( 'sankor.bsky.social' );

Unblocks a user.

Expected parameters include:

=over

=item C<identifier> - required

Handle or DID of the person you'd like to block.

=back

Returns a true value on success.

=head2 C<follow( ... )>

    $bsky->follow( 'sankor.bsky.social' );

Follow a user.

Expected parameters include:

=over

=item C<identifier> - required

Handle or DID of the person you'd like to follow.

=back

Returns a true value on success.

=head2 C<unfollow( ... )>

    $bsky->unfollow( 'sankor.bsky.social' );

Unfollows a user.

Expected parameters include:

=over

=item C<identifier> - required

Handle or DID of the person you'd like to unfollow.

=back

Returns a true value on success.

=head2 C<post( ... )>

    $bsky->post( text => 'Hello, world!' );

Create a new post.

Expected parameters include:

=over

=item C<text> - required

Text content of the post. Must be 300 characters or fewer.

=back

Note: This method will grow to support more features in the future.

Returns the CID and AT-URI values on success.

=head2 C<delete( ... )>

    $bsky->delete( 'at://...' );

Delete a post.

Expected parameters include:

=over

=item C<url> - required

The AT-URI of the post.

=back

Returns a true value on success.

=head2 C<profile( ... )>

    $bsky->profile( 'sankor.bsky.social' );

Gathers profile data.

Expected parameters include:

=over

=item C<identifier> - required

Handle or DID of the person you'd like information on.

=back

Returns a hash of data on success.

=head1 Error Handling

Exception handling is carried out by returning objects with untrue boolean values.

=head1 See Also

L<App::bsky> - Bluesky client on the command line

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2. Other copyrights, terms, and conditions may apply to data transmitted through this module.

=head1 AUTHOR

Sanko Robinson E<lt>sanko@cpan.orgE<gt>

=begin stopwords

atproto Bluesky unfollow reposts auth authed login aka eg

=end stopwords

=cut
