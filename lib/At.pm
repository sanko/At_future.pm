package At 1.0 {
    use v5.38;
    use warnings::register;
    use experimental qw[try for_list];
    use diagnostics;
    no warnings qw[experimental::builtin];
    use parent               qw[Exporter];
    use Carp                 qw[carp confess];
    use File::ShareDir::Tiny qw[dist_dir module_dir];
    use JSON::Tiny           qw[decode_json];
    use Path::Tiny           qw[path];
    use Time::Moment;    # Internal; standardize around Zulu
    use URI;
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
        $args{http} //= Mojo::UserAgent->can('start') ? At::UserAgent::Mojo->new(%args) : At::UserAgent::Tiny->new(%args);
        bless {
            http       => $args{http},
            service    => $args{service},
            ratelimits => {                 #~ https://docs.bsky.app/docs/advanced-guides/rate-limits
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
            At => sprintf '%.2f of %s rate limit remaining (%d of %d). Slow down or try again in %s',
            $percent, $type, $rate->{remaining}, $rate->{limit}, _duration( $rate->{reset} - time )
        ) if $percent <= 5;
    }

    sub did ($s) {
        my $session = $s->{http}->session;
        defined $session ? $session->{did} : ();
    }

    sub session($s) {
        $s->{http}->session;
    }
    #
    sub createAccount ( $s, %args ) {
        my $session = At::com::atproto::server::createAccount( $s, %args );
        $s->{http}->_set_session($session) if $session;
        $session;
    }

    sub login ( $s, %args ) {
        my ( $session, $headers ) = At::com::atproto::server::createSession( $s, %args );
        $session || return $session;
        $s->{http}->_set_session($session);
        $session;
    }

    sub getTimeline ( $s, %args ) {
        At::app::bsky::feed::getTimeline( $s, %args );
    }

    sub getAuthorFeed ( $s, %args ) {
        At::app::bsky::feed::getAuthorFeed( $s, %args );
    }

    sub getPostThread ( $s, %args ) {
        At::app::bsky::feed::getPostThread( $s, %args );
    }

    sub getPost ( $s, $uri ) {
        At::app::bsky::feed::getPosts( $s, uris => [$uri] );
    }

    sub getPosts ( $s, %args ) {
        At::app::bsky::feed::getPosts( $s, %args );
    }

    sub getLikes ( $s, %args ) {
        At::app::bsky::feed::getLikes( $s, %args );
    }

    sub getRepostedBy ( $s, %args ) {
        At::app::bsky::feed::getRepostedBy( $s, %args );
    }

    #~ await agent.getRepostedBy(params, opts)
    #~ await agent.post(record)
    #~ await agent.deletePost(postUri)
    #~ await agent.like(uri, cid)
    #~ await agent.deleteLike(likeUri)
    #~ await agent.repost(uri, cid)
    #~ await agent.deleteRepost(repostUri)
    #~ await agent.uploadBlob(data, opts)
    # Jumping ahead for a sec
    sub getProfile ( $s, %args ) {
        At::app::bsky::actor::getProfile( $s, %args );
    }

    sub upsertProfile ( $s, $fn ) {
        my $repo = $s->did;
        my $existing;
        for ( 0 .. 5 ) {    # Might take a few tries
            $existing ||= At::com::atproto::repo::getRecord( $s, repo => $repo->as_string, collection => 'app.bsky.actor.profile', rkey => 'self' );
            my %updated = $fn->( %{ $existing->{value} } );
            my $okay    = At::com::atproto::repo::putRecord(
                $s,
                repo       => $repo->as_string,
                collection => 'app.bsky.actor.profile',
                rkey       => 'self',
                record     => { %updated, type => 'app.bsky.actor.profile' },
                swapRecord => $existing ? $existing->{cid} : undef
            );
            return $okay if $okay;
        }
        ();
    }
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
                    }
                    elsif ( $schema->{type} eq 'object' ) {
                        _set_capture( $fqdn, $schema );
                    }
                    elsif ( $schema->{type} eq 'procedure' ) {
                        my @namespace = split /\./, $fqdn;
                        no strict 'refs';
                        my $rate_category
                            = $namespace[-1] =~ m[^(updateHandle|createAccount|createSession|deleteAccount|resetPassword)$] ? $namespace[-1] :
                            'global';
                        *{ join '::', 'At', @namespace } = sub ( $s, %args ) {
                            my $_rate_meta
                                = $rate_category eq 'createSession' ? $args{identifier} : $rate_category eq 'updateHandle' ? $args{did} : ();
                            $s->_ratecheck( $rate_category, $_rate_meta );
                            my ( $content, $headers ) = $s->{http}->post( $s->{service}->as_string . ( '/xrpc/' . $fqdn ), { content => \%args } );

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
                        *{ join '::', 'At', @namespace } = sub ( $s, %args ) {
                            $s->_ratecheck('global');

                            # ddx $schema;
                            my ( $content, $headers ) = $s->{http}->get( $s->{service}->as_string . ( '/xrpc/' . $fqdn ), { content => \%args } );

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
                    elsif ( $schema->{type} eq 'string' )       { }
                    elsif ( $schema->{type} eq 'subscription' ) { }
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
                elsif ( $schema->{format} eq 'at-uri' ) { return At::URI->new($data); }
                elsif ( $schema->{format} eq 'cid' )    { return $data; }                 # TODO
                elsif ( $schema->{format} eq 'datetime' ) {
                    return $data =~ /\D/ ? Time::Moment->from_string($data) : Time::Moment->from_epoch($data);
                }
                elsif ( $schema->{format} eq 'did' ) {
                    confess 'malformed DID URI: ' . $data unless $data =~ /^did:([a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-])$/;
                    $data = URI->new($data) unless builtin::blessed $data;
                    my $scheme = $data->scheme;
                    carp 'unsupported method: ' . $scheme unless $scheme =~ m/^(did|plc|web)$/;
                    return $data;
                }
                elsif ( $schema->{format} eq 'handle' ) {
                    confess 'malformed handle: ' . $data
                        unless $data =~ /^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/;
                    confess 'disallowed TLD in handle: ' . $data if $data =~ /\.(arpa|example|internal|invalid|local|localhost|onion)$/;
                    CORE::state $warned //= 0;
                    if ( $data =~ /\.(test)$/ && !$warned ) {
                        carp 'development or testing TLD used in handle: ' . $data;
                        $warned = 1;
                    }
                    return $data;
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
        die 'Unknown coercion: ' . $schema->{type};
    }
}
package    #
    At::URI::_query 1.0 {
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
}
package              #
    At::URI 1.0 {    # https://atproto.com/specs/at-uri-scheme
    use v5.38;
    use URI::_query;

    #~ use builtin qw[blessed];
    no warnings qw[experimental::builtin];
    use overload
        '""' => sub ( $s, $u, $q ) {
        $s->as_string;
        };

    sub ATP_URI_REGEX () {

        #   proto-    --did--------------   --name----------------   --path----   --query--   --hash--
        qr/^(at:\/\/)?((?:did:[a-z0-9:%-]+)|(?:[a-z0-9][a-z0-9.:-]*))(\/[^?#\s]*)?(\?[^#\s]+)?(#[^\s]+)?$/i;
    }

    sub RELATIVE_REGEX () {

        #   --path-----   --query--  --hash--
        qr/^(\/[^?#\s]*)?(\?[^#\s]+)?(#[^\s]+)?$/i;
    }

    sub new( $class, $uri ) {
        $uri = URI->new($uri) unless builtin::blessed $uri;
        use Data::Dump;
        my @res = $uri->as_string =~ ATP_URI_REGEX();
        bless { hash => $res[4] // '', host => $res[1] // '', pathname => $res[2] // '', searchParams => At::URI::_query->new( $res[3] // '' ) },
            $class;
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
}
package    #
    At::Error 1.0 {
    use v5.38;
    use overload
        bool => sub {0},
        '""' => sub ( $s, $u, $q ) { $s->{message} // 'Unknown error' };
    sub new ( $class, $args ) { bless $args, $class }
}
package    #
    At::UserAgent 1.0 {
    use v5.38;
    sub new  {...}
    sub get  {...}
    sub post {...}
    sub _set_session ( $s, $session ) {...}
    sub session      ($s)             {...}
    sub ratelimit    ($s)             {...}
}
package    #
    At::UserAgent::Tiny 1.0 {
    use v5.38;
    use parent -norequire, 'At::UserAgent';
    use HTTP::Tiny;
    use JSON::Tiny qw[decode_json encode_json];
    use warnings::register;
    no warnings qw[experimental::builtin];
    #
    sub new ( $class, %args ) {
        $args{agent} //= HTTP::Tiny->new(
            agent           => sprintf( 'At.pm/%1.2f; ', $At::VERSION ),
            default_headers => {
                'Content-Type' => 'application/json',
                Accept         => 'application/json',
                ( $args{'language'} ? ( 'Accept-Language' => $args{'language'} ) : () )
            }
        );
        bless \%args, $class;
    }

    sub get ( $s, $url, $req = () ) {
        my $res
            = $s->{agent}
            ->get( $url . ( defined $req->{content} && keys %{ $req->{content} } ? '?' . $s->{agent}->www_form_urlencode( $req->{content} ) : '' ),
            { defined $req->{headers} ? ( headers => $req->{headers} ) : () } );
        if ( !$res->{success} ) {
            my $err = At::Error->new( decode_json $res->{content} );
            return wantarray ? ( $err, $res->{headers} ) : $err;
        }
        $res->{content} = decode_json $res->{content} if $res->{content} && $res->{headers}{'content-type'} =~ m[application/json];
        wantarray ? ( $res->{content}, $res->{headers} ) : $res->{content};
    }

    sub post ( $s, $url, $req = () ) {
        my $res = $s->{agent}->post(
            $url,
            {   defined $req->{headers} ? ( headers => $req->{headers} )                                                     : (),
                defined $req->{content} ? ( content => ref $req->{content} ? encode_json $req->{content} : $req->{content} ) : ()
            }
        );
        if ( !$res->{success} ) {
            my $err = At::Error->new( decode_json $res->{content} );
            return wantarray ? ( $err, $res->{headers} ) : $err;
        }
        $res->{content} = decode_json $res->{content} if $res->{content} && $res->{headers}{'content-type'} =~ m[application/json];
        wantarray ? ( $res->{content}, $res->{headers} ) : $res->{content};
    }
    sub websocket ( $s, $url, $req = () ) {...}

    sub _set_session ( $s, $session ) {
        $s->{session} = $session;
        $s->_set_bearer_token( 'Bearer ' . $s->{session}{accessJwt} );
    }

    sub session ($s) {
        $s->{session};
    }

    sub _set_bearer_token ( $s, $token ) {
        $s->{agent}->{default_headers}{Authorization} = $token;
    }

    sub ratelimit($s) {
        $s->{ratelimit} // ();
    }
}
package    #
    At::UserAgent::Mojo 1.0 {
    use v5.38;
    use parent -norequire, 'At::UserAgent';
}
package    #
    At::UserAgent::Async 1.0 {
    use v5.38;
    use parent -norequire, 'At::UserAgent';
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

Gather the DID of the current user. Returns c<undef> if the client is not authenticated.

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
