use v5.40;
use Data::Dump;
use Path::Tiny qw[path];
use JSON::Tiny qw[decode_json];
$|++;
#
my $lexicons = path('../share/lexicons');
my %output   = (
    at_pm            => path('./lib/At.pm'),
    at_pod           => path('./lib/At.pod'),
    at_bsky_pm       => path('./lib/At/Bluesky.pm'),
    at_bsky_pod      => path('./lib/At/Bluesky.pod'),
    at_bsky_chat_pm  => path('./lib/At/Bluesky/Chat.pm'),
    at_bsky_chat_pod => path('./lib/At/Bluesky/Chat.pod'),
    at_ozone_pm      => path('./lib/At/Ozone.pm'),
    at_ozone_pod     => path('./lib/At/Ozone.pod')
);
#
$_->remove for values %output;
$_->parent->mkpath for values %output;
#
$output{at_pm}->append_raw(<<'END');
package At 0.18 {
    use v5.40.0;
    no warnings 'experimental::class', 'experimental::builtin', 'experimental::for_list';    # Be quiet.
    use feature 'class';
    use experimental 'try';
    #
    #~ use At::Lexicon::com::atproto::label;
    #~ use At::Lexicon::com::atproto::admin;
    #~ use At::Lexicon::com::atproto::moderation;

    #~ |---------------------------------------|
    #~ |------3-33-----------------------------|
    #~ |-5-55------4-44-5-55----353--3-33-/1~--|
    #~ |---------------------335---33----------|
    class At {

        sub _decode_token ($token) {
            use MIME::Base64 qw[decode_base64];
            use JSON::Tiny   qw[decode_json];
            my ( $header, $payload, $sig ) = split /\./, $token;
            $payload =~ tr[-_][+/];    # Replace Base64-URL characters with standard Base64
            decode_json decode_base64 $payload;
        }

        sub resume ( $class, %config ) {    # store $at->http->session->_raw and restore it here
            my $at      = builtin::blessed $class ? $class : $class->new();    # Expect a blessed object
            my $access  = _decode_token $config{accessJwt};
            my $refresh = _decode_token $config{refreshJwt};
            if ( time > $access->{exp} && time < $refresh->{exp} ) {

                # Attempt to use refresh token which has a 90 day life span as of Jan. 2024
                my $session = $at->server_refreshSession( $config{refreshJwt} );
                $at->http->set_session($session);
            }
            else {
                $at->http->set_session( \%config );
            }
            $at;
        }
        field $http //= Mojo::UserAgent->can('start') ? At::UserAgent::Mojo->new() : At::UserAgent::Tiny->new();
        method http {$http}
        field $host : param = ();
        field $repo : param = ();
        field $identifier : param //= ();
        field $password : param   //= ();
        #
        field $did : param = ();    # do not allow arg to new
        method did {$did}

        # Allow session restoration
        field $accessJwt : param  //= ();
        field $refreshJwt : param //= ();
        #
        method host {
            return $host if defined $host;
            use Carp qw[confess];
            confess 'You must provide a host or perhaps you wanted At::Bluesky';
        }

        method session() {
            return unless defined $http && defined $http->session;
            $http->session->_raw;
        }
        ## Internals
        sub _now {
            At::Protocol::Timestamp->new( timestamp => time );
        }
        ADJUST {
            $host = $self->host() unless defined $host;
            if ( defined $host ) {
                $host = 'https://' . $host unless $host =~ /^https?:/;
                $host = URI->new($host)    unless builtin::blessed $host;
                if ( defined $accessJwt && defined $refreshJwt && defined $did ) {
                    $http->set_session( { accessJwt => $accessJwt, refreshJwt => $refreshJwt, did => $did } );
                    $did = At::Protocol::DID->new( uri => $did );
                }
                elsif ( defined $identifier && defined $password ) {    # auto-login
                    my $session = $self->server_createSession( identifier => $identifier, password => $password );
                    if ( defined $session->{accessJwt} ) {
                        $http->set_session($session);
                        $did = At::Protocol::DID->new( uri => $http->session->did->_raw );
                    }
                    else {
                        use Carp qw[carp];
                        carp 'Error creating session' . ( defined $session->{message} ? ': ' . $session->{message} : '' );

                        #~ undef $self;
                    }
                }
            }
        }
END
$output{at_pod}->append_raw(<<'END');
=pod

=encoding utf-8

=head1 NAME

At - The AT Protocol for Social Networking

=head1 SYNOPSIS

    use At;
    my $at = At->new( host => 'https://fun.example' );
    $at->server_createSession( 'sanko', '1111-aaaa-zzzz-0000' );
    $at->repo_createRecord(
        repo       => $at->did,
        collection => 'app.bsky.feed.post',
        record     => { '$type' => 'app.bsky.feed.post', text => 'Hello world! I posted this via the API.', createdAt => time }
    );

=head1 DESCRIPTION

Bluesky is backed by the AT Protocol, a "social networking technology created to power the next generation of social
applications."

At.pm uses perl's new class system which requires perl 5.38.x or better and, like the protocol itself, is still under
development.

=head2 At::Bluesky

At::Bluesky is a subclass with the host set to C<https://bluesky.social> and all the lexicon related to the social
networking site included.

=head2 App Passwords

Taken from the AT Protocol's official documentation:

=for html <blockquote>

For the security of your account, when using any third-party clients, please generate an L<app
password|https://atproto.com/specs/xrpc#app-passwords> at Settings > Advanced > App passwords.

App passwords have most of the same abilities as the user's account password, but they're restricted from destructive
actions such as account deletion or account migration. They are also restricted from creating additional app passwords.

=for html </blockquote>

Read their disclaimer here: L<https://atproto.com/community/projects#disclaimer>.

=head1 Methods

The API attempts to follow the layout of the underlying protocol so changes to this module might be beyond my control.

=head2 C<new( ... )>

    my $at = At->new( host => 'https://bsky.social' );

Creates an AT client and initiates an authentication session.

Expected parameters include:

=over

=item C<host> - required

Host for the account. If you're using the 'official' Bluesky, this would be 'https://bsky.social' but you'll probably
want C<At::Bluesky-E<gt>new(...)> because that client comes with all the bits that aren't part of the core protocol.

=back

=head2 C<resume( ... )>

    my $at = At->resume( $session );

Resumes an authenticated session.

Expected parameters include:

=over

=item C<session> - required

=back

=head2 C<session( )>

    my $restore = $at->session;

Returns data which may be used to resume an authenticated session.

Note that this data is subject to change in line with the AT protocol.

END
$output{at_bsky_pm}->append_raw(<<'END');
package At::Bluesky {
    use v5.40.0;
    use Object::Pad;
    no warnings 'experimental::builtin';    # Be quiet.
    use At;
    use Carp;
    #
    #~ use At::Lexicon::com::atproto::label;
    #~ use At::Lexicon::app::bsky::actor;
    #~ use At::Lexicon::app::bsky::embed;
    #~ use At::Lexicon::app::bsky::graph;
    #~ use At::Lexicon::app::bsky::richtext;
    #~ use At::Lexicon::app::bsky::notification;
    #~ use At::Lexicon::app::bsky::feed;
    #~ use At::Lexicon::app::bsky::unspecced;
    #
    class At::Bluesky : isa(At) {
        field $_host : param(_host) //= 'https://bsky.social';

        # Required in subclasses of At
        method host { URI->new($_host) }
END

END {
    $output{at_pm}->append_raw(<<'END');

        class At::Protocol::DID {    # https://atproto.com/specs/did
            use overload '""' => sub {shift->_raw};
            field $uri : param;
            ADJUST {
                use Carp qw[carp confess];
                confess 'malformed DID URI: ' . $uri unless $uri =~ /^did:([a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-])$/;
                use URI;
                $uri = URI->new($1) unless builtin::blessed $uri;
                my $scheme = $uri->scheme;
                carp 'unsupported method: ' . $scheme if $scheme ne 'plc' && $scheme ne 'web';
            };

            method _raw {
                'did:' . $uri->as_string;
            }
        }

        class At::Protocol::Timestamp {    # Internal; standardize around Zulu
            field $timestamp : param;
            ADJUST {
                use Time::Moment;
                if ( !builtin::blessed $timestamp ) {
                    $timestamp = $timestamp =~ /\D/ ? Time::Moment->from_string($timestamp) : Time::Moment->from_epoch($timestamp);
                }
            };

            method _raw {
                $timestamp->to_string;
            }
        }

        class At::Protocol::Handle {    # https://atproto.com/specs/handle
            field $id : param;
            ADJUST {
                use Carp qw[confess carp];
                confess 'malformed handle: ' . $id
                    unless $id =~ /^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/;
                confess 'disallowed TLD in handle: ' . $id if $id =~ /\.(arpa|example|internal|invalid|local|localhost|onion)$/;
                CORE::state $warned //= 0;
                if ( $id =~ /\.(test)$/ && !$warned ) {
                    carp 'development or testing TLD used in handle: ' . $id;
                    $warned = 1;
                }
            };
            method _raw { $id; }
        }

        class At::Protocol::Session {
            field $accessJwt : param;
            field $did : param;
            field $didDoc : param         = ();    # spec says 'unknown' so I'm just gonna ignore it for now even with the dump
            field $email : param          = ();
            field $emailConfirmed : param = ();
            field $handle : param         = ();
            field $refreshJwt : param;

            # waiting for perlclass to implement accessors with :reader
            method accessJwt  {$accessJwt}
            method did        {$did}
            method refreshJwt {$refreshJwt}
            method handle     {$handle}
            #
            ADJUST {
                # warn "ADJUST";
                $did            = At::Protocol::DID->new( uri => $did ) unless builtin::blessed $did;
                $handle         = At::Protocol::Handle->new( id => $handle ) if defined $handle && !builtin::blessed $handle;
                $emailConfirmed = !!$emailConfirmed                          if defined $emailConfirmed;
            }

            # This could be used as part of a session resume system
            method _raw {
                +{  accessJwt => $accessJwt,
                    did       => $did->_raw,
                    defined $didDoc ? ( didDoc => $didDoc ) : (), defined $email ? ( email => $email ) : (),
                    defined $emailConfirmed ? ( emailConfirmed => \!!$emailConfirmed ) : (),
                    refreshJwt => $refreshJwt,
                    defined $handle ? ( handle => $handle->_raw ) : ()
                };
            }
        }

        class At::UserAgent {
            field $session : param = ();
            method session ( ) { $session; }

            method set_session ($s) {
                $session = builtin::blessed $s ? $s : At::Protocol::Session->new(%$s);
                $self->_set_bearer_token( 'Bearer ' . $s->{accessJwt} );
            }
            method get       ( $url, $req = () ) {...}
            method post      ( $url, $req = () ) {...}
            method websocket ( $url, $req = () ) {...}
            method _set_bearer_token ($token) {...}
        }

        class At::UserAgent::Tiny : isa(At::UserAgent) {

            # TODO: Error handling
            use HTTP::Tiny;
            use JSON::Tiny qw[decode_json encode_json];
            field $agent : param = HTTP::Tiny->new(
                agent           => sprintf( 'At.pm/%1.2f;Tiny ', $At::VERSION ),
                default_headers => { 'Content-Type' => 'application/json', Accept => 'application/json' }
            );

            method get ( $url, $req = () ) {
                my $res
                    = $agent->get(
                    $url . ( defined $req->{content} && keys %{ $req->{content} } ? '?' . $agent->www_form_urlencode( $req->{content} ) : '' ),
                    { defined $req->{headers} ? ( headers => $req->{headers} ) : () } );

                #~ use Data::Dump;
                #~ warn $url . ( defined $req->{content} && keys %{ $req->{content} } ? '?' . _build_query_string( $req->{content} ) : '' );
                #~ ddx $res;
                return $res->{content} = decode_json $res->{content} if $res->{content} && $res->{headers}{'content-type'} =~ m[application/json];
                return $res;
            }

            method post ( $url, $req = () ) {

                #~ use Data::Dump;
                #~ warn $url;
                #~ ddx $req;
                #~ ddx encode_json $req->{content} if defined $req->{content} && ref $req->{content};
                my $res = $agent->post(
                    $url,
                    {   defined $req->{headers} ? ( headers => $req->{headers} )                                                     : (),
                        defined $req->{content} ? ( content => ref $req->{content} ? encode_json $req->{content} : $req->{content} ) : ()
                    }
                );

                #~ ddx $res;
                return $res->{content} = decode_json $res->{content} if $res->{content} && $res->{headers}{'content-type'} =~ m[application/json];
                return $res;
            }
            method websocket ( $url, $req = () ) {...}

            method _set_bearer_token ($token) {
                $agent->{default_headers}{Authorization} = $token;
            }
        }

        class At::UserAgent::Mojo : isa(At::UserAgent) {

            # TODO - Required for websocket based Event Streams
            #~ https://atproto.com/specs/event-stream
            # TODO: Error handling
            field $agent : param = sub {
                my $ua = Mojo::UserAgent->new;
                $ua->transactor->name( sprintf( 'At.pm/%1.2f;Mojo', $At::VERSION ) );
                $ua;
                }
                ->();
            method agent {$agent}
            field $auth : param //= ();

            method get ( $url, $req = () ) {
                my $res = $agent->get(
                    $url,
                    defined $auth           ? { Authorization => $auth, defined $req->{headers} ? %{ $req->{headers} } : () } : (),
                    defined $req->{content} ? ( form => $req->{content} )                                                     : ()
                );
                $res = $res->result;

                # todo: error handling
                if ( $res->is_success ) {
                    return $res->content ? $res->headers->content_type =~ m[application/json] ? $res->json : $res->content : ();
                }
                elsif ( $res->is_error )    { CORE::say $res->message }
                elsif ( $res->code == 301 ) { CORE::say $res->headers->location }
                else                        { CORE::say 'Whatever...' }
            }

            method post ( $url, $req = () ) {

                #~ warn $url;
                my $res = $agent->post(
                    $url,
                    defined $auth ? { Authorization => $auth, defined $req->{headers} ? %{ $req->{headers} } : () } : (),
                    defined $req->{content} ? ref $req->{content} ? ( json => $req->{content} ) : $req->{content} : ()
                )->result;

                # todo: error handling
                if ( $res->is_success ) {
                    return $res->content ? $res->headers->content_type =~ m[application/json] ? $res->json : $res->content : ();
                }
                elsif ( $res->is_error )    { CORE::say $res->message }
                elsif ( $res->code == 301 ) { CORE::say $res->headers->location }
                else                        { CORE::say 'Whatever...' }
            }

            method websocket ( $url, $cb, $req = () ) {
                require CBOR::Free::SequenceDecoder;
                $agent->websocket(
                    $url => { 'Sec-WebSocket-Extensions' => 'permessage-deflate' } => sub ( $ua, $tx ) {

                        #~ use Data::Dump;
                        #~ ddx $tx;
                        CORE::say 'WebSocket handshake failed!' and return unless $tx->is_websocket;

                        #~ CORE::say 'Subprotocol negotiation failed!' and return unless $tx->protocol;
                        #~ $tx->send({json => {test => [1, 2, 3]}});
                        $tx->on(
                            finish => sub ( $tx, $code, $reason ) {
                                CORE::say "WebSocket closed with status $code.";
                            }
                        );
                        CORE::state $decoder //= CBOR::Free::SequenceDecoder->new()->set_tag_handlers( 42 => sub { } );

                        #~ $tx->on(json => sub ($ws, $hash) { CORE::say "Message: $hash->{msg}" });
                        $tx->on(
                            message => sub ( $tx, $msg ) {
                                my $head = $decoder->give($msg);
                                my $body = $decoder->get;

                                #~ ddx $$head;
                                $$body->{blocks} = length $$body->{blocks} if defined $$body->{blocks};

                                #~ use Data::Dumper;
                                #~ CORE::say Dumper $$body;
                                $cb->($$body);

                                #~ CORE::say "WebSocket message: $msg";
                                #~ $tx->finish;
                            }
                        );

                        #~ $tx->on(
                        #~ frame => sub ( $ws, $frame ) {
                        #~ ddx $frame;
                        #~ }
                        #~ );
                        #~ $tx->on(
                        #~ text => sub ( $ws, $bytes ) {
                        #~ ddx $bytes;
                        #~ }
                        #~ );
                        #~ $tx->send('Hi!');
                    }
                );
            }

            method _set_bearer_token ($token) {
                $auth = $token;
            }
        }
    }

    sub _glength ($str) {    # https://www.perl.com/pub/2012/05/perlunicook-string-length-in-graphemes.html/
        my $count = 0;
        while ( $str =~ /\X/g ) { $count++ }
        return $count;
    }

    sub _topkg ($name) {     # maps CID to our packages (I hope)
        $name =~ s/[\.\#]/::/g;
        $name =~ s[::defs::][::];

        #~ $name =~ s/^(.+::)(.*?)#(.*)$/$1$3/;
        return 'At::Lexicon::' . $name;
    }
}
1;
END
    $output{at_pod}->append_raw(<<'END');

=begin todo

=head1 Services

Currently, there are 3 sandbox At Protocol services:

=over

=item PLC

    my $at = At->new( host => 'plc.bsky-sandbox.dev' );

This is the default DID provider for the network. DIDs are the root of your identity in the network. Sandbox PLC
functions exactly the same as production PLC, but it is run as a separate service with a separate dataset. The DID
resolution client in the self-hosted PDS package is set up to talk the correct PLC service.

=item BGS

    my $at = At->new( host => 'bgs.bsky-sandbox.dev' );

BGS (Big Graph Service) is the firehose for the entire network. It collates data from PDSs & rebroadcasts them out on
one giant websocket.

BGS has to find out about your server somehow, so when we do any sort of write, we ping BGS with
com.atproto.sync.requestCrawl to notify it of new data. This is done automatically in the self-hosted PDS package.

If you’re familiar with the Bluesky production firehose, you can subscribe to the BGS firehose in the exact same
manner, the interface & data should be identical

=item BlueSky Sandbox

    my $at = At->new( host => 'api.bsky-sandbox.dev' );

The Bluesky App View aggregates data from across the network to service the Bluesky microblogging application. It
consumes the firehose from the BGS, processing it into serviceable views of the network such as feeds, post threads,
and user profiles. It functions as a fairly traditional web service.

When you request a Bluesky-related view from your PDS (getProfile for instance), your PDS will actually proxy the
request up to App View.

Feel free to experiment with running your own App View if you like!

=back

You may also configure your own personal data server (PDS).

    my $at = At->new( host => 'your.own.com' );

PDS (Personal Data Server) is where users host their social data such as posts, profiles, likes, and follows. The goal
of the sandbox is to federate many PDS together, so we hope you’ll run your own.

We’re not actually running a Bluesky PDS in sandbox. You might see Bluesky team members' accounts in the sandbox
environment, but those are self-hosted too.

The PDS that you’ll be running is much of the same code that is running on the Bluesky production PDS. Notably, all
of the in-pds-appview code has been torn out. You can see the actual PDS code that you’re running on the
atproto/simplify-pds branch.

=end todo

=head1 See Also

L<App::bsky> - Bluesky client on the command line

L<https://atproto.com/>

L<https://bsky.app/profile/atperl.bsky.social>

L<Bluesky on Wikipedia.org|https://en.wikipedia.org/wiki/Bluesky_(social_network)>

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2. Other copyrights, terms, and conditions may apply to data transmitted through this module.

=head1 AUTHOR

Sanko Robinson E<lt>sanko@cpan.orgE<gt>

=begin stopwords

didDoc cids cid websocket emails communicationTemplates signup signups diff auth did:plc atproto proxying aka mimetype
nullable versioning refreshJwt accessJwt golang seq eg CIDso

=end stopwords

=cut

END
    $output{at_bsky_pm}->append_raw(<<'END');
    }
};
END
}
ddx $lexicons;
#
sub id2namespace($id) {
    join '::', qw[At Lexicon], grep { $_ ne 'defs' } split /\./, $id;
}
#
my %state;
my %types;
say <<END;
use v5.40;
use feature 'class';
no warnings 'experimental::class';
use Carp qw[];
END

# collect files sizes
my $sizes = $lexicons->visit(
    sub {
        my ( $path, $state ) = @_;
        return if $path->is_dir;
        $state{$path} = { size => -s $path, raw => decode_json $path->slurp_raw };
        my $raw = decode_json $path->slurp_raw;
        return if !$raw->{lexicon};

        #~ say sprintf <<'END', id2namespace( $raw->{id} ), $raw->{lexicon};
        #~ package %s v1.0.%d;
        #~ END
        for my $name ( sort keys %{ $raw->{defs} } ) {
            my $def = $raw->{defs}{$name};
            if ( $def->{type} eq 'object' ) {
                my @ADJUST;
                say sprintf '    class %s v1.0.%d {', id2namespace( $raw->{id} . '.' . $name ), $raw->{lexicon};
                for my $field ( sort keys %{ $def->{properties} } ) {
                    my $type = $def->{properties}{$field};
                    say '   field $' .
                        $field .
                        ' :param :reader ' . (
                        defined $type->{const}       ? q[= '] . delete( $type->{const} ) . q['] :
                            defined $type->{default} ? q[//= '] . delete( $type->{default} ) . q['] :
                            '' ) .
                        '; # ' .
                        $type->{type};
                    if ( $type->{type} eq 'array' ) {
                        delete $type->{type};
                        delete $type->{description};
                        delete $type->{items};
                        warn 'Unhandled array item validation!';
                        push @ADJUST, sprintf 'Carp::cluck q[%s has too many elements] if defined $%s && scalar @$%s > %d', $field, $field, $field,
                            delete $type->{maxLength}
                            if defined $type->{maxLength};
                        push @ADJUST, sprintf 'Carp::cluck q[%s requires more elements] if defined $%s && scalar @$%s < %d', $field, $field, $field,
                            delete $type->{minLength}
                            if defined $type->{minLength};
                    }
                    elsif ( $type->{type} eq 'blob' ) {
                        say '# ' . Data::Dump::pp($type);
                        $type = {};
                    }
                    elsif ( $type->{type} eq 'boolean' ) {
                        delete $type->{type};
                    }
                    elsif ( $type->{type} eq 'bytes' ) {
                        delete $type->{type};
                        push @ADJUST, sprintf 'Carp::cluck q[%s is too long] if defined $%s && length $%s > %d', $field, $field, $field,
                            delete $type->{maxLength}
                            if defined $type->{maxLength};
                    }
                    elsif ( $type->{type} eq 'integer' ) {
                        delete $type->{type};
                        push @ADJUST, sprintf 'Carp::cluck q[%s is below the minimum] if defined $%s && $%s < %d', $field, $field, $field,
                            delete $type->{minimum}
                            if defined $type->{minimum};
                        push @ADJUST, sprintf 'Carp::cluck q[%s is above the maximum] if defined $%s && $%s > %d', $field, $field, $field,
                            delete $type->{maximum}
                            if defined $type->{maximum};
                    }
                    elsif ( $type->{type} eq 'object' ) {
                    }
                    elsif ( $type->{type} eq 'ref' ) {
                        warn 'Unhandled ref type!!!!!!!!!!!!!!!!!!!!!!';
                        delete $type->{type};
                        delete $type->{ref};
                    }
                    elsif ( $type->{type} eq 'string' ) {
                        {
                            if ( defined $type->{minLength} ) {
                                push @ADJUST, sprintf 'Carp::cluck q[%s is too short] if defined $%s && length $%s < %d', $field, $field, $field,
                                    delete $type->{minLength};
                            }
                            if ( defined $type->{maxLength} ) {
                                push @ADJUST, sprintf 'Carp::cluck q[%s is too long] if defined $%s && length $%s > %d', $field, $field, $field,
                                    delete $type->{maxLength};
                            }
                            if ( defined $type->{maxGraphemes} ) {
                                push @ADJUST, sprintf 'Carp::cluck q[%s is too long] if defined $%s && At::_glength($%s) > %d', $field, $field,
                                    $field, delete $type->{maxGraphemes};
                            }
                        }
                        {
                            if ( defined $type->{knownValues} ) {
                                push @ADJUST, sprintf 'Carp::cluck q[Unexpected value for %s: ] . $%s unless grep {$%s eq $_ } %s', $field, $field,
                                    $field, join ', ', map { q['] . $_ . q['] } @{ $type->{knownValues} };
                                delete $type->{knownValues};
                            }
                        }
                        {
                            if    ( !defined $type->{format} ) { }
                            elsif ( $type->{format} eq 'at-identifier' ) {

                                # No validation (yet)
                                #~ ddx $type;
                            }
                            elsif ( $type->{format} eq 'at-uri' ) {
                                push @ADJUST, sprintf '$%s = URI->new( $%s ) unless builtin::blessed $%s;', $field, $field, $field;
                            }
                            elsif ( $type->{format} eq 'cid' ) {

                                # No validation (yet)
                            }
                            elsif ( $type->{format} eq 'datetime' ) {
                                ddx $type;
                                push @ADJUST, sprintf '$%s = At::Protocol::Timestamp->new( timestamp => $%s ) unless builtin::blessed $%s;', $field,
                                    $field, $field;
                            }
                            elsif ( $type->{format} eq 'did' ) {
                                push @ADJUST, sprintf '$%s = At::Protocol::DID->new( uri => $%s ) unless builtin::blessed $%s;', $field, $field,
                                    $field;
                            }
                            elsif ( $type->{format} eq 'handle' ) {
                                push @ADJUST, sprintf '$%s = At::Protocol::Handle->new( id => $%s ) unless builtin::blessed $%s;', $field, $field,
                                    $field;
                            }
                            elsif ( $type->{format} eq 'language' ) {

                                # No validation (yet)
                            }
                            elsif ( $type->{format} eq 'nsid' ) {

                                # No validation (yet)
                            }
                            elsif ( $type->{format} eq 'uri' ) {
                                push @ADJUST, sprintf '$%s = URI->new( $%s ) unless builtin::blessed $%s;', $field, $field, $field;
                            }
                            else {
                                ddx $type;
                                die 'Unhandled string format';
                            }
                            delete $type->{format};
                        }
                        delete $type->{type};
                        delete $type->{description};
                        if ( keys %{$type} ) {
                            ddx $type;
                            die 'Unhandled string format';
                        }
                    }
                    elsif ( $type->{type} eq 'cid-link' ) {
                        delete $type->{type};
                    }
                    elsif ( $type->{type} eq 'union' ) {
                        push @ADJUST, '# TODO: union $' . $name, Data::Dump::pp($type);
                        $type = {};
                    }
                    elsif ( $type->{type} eq 'unknown' ) {

                        # No validation required
                        delete $type->{type};
                    }
                    else {
                        ddx $type;
                        die 'Unhandled field type';
                    }
                    delete $type->{description};
                    if ( keys %$type ) {
                        ddx $type;
                        die 'Unhandled type stuff';
                    }
                    ddx $type;
                }
                ddx $def;
                if (@ADJUST) {
                    say '    ADJUST{';
                    say '        ' . $_ . ';' for @ADJUST;
                    say '    }';
                }
                say 'method _raw(){ ... }';

                #~ ...;
                say '    };';
            }
            elsif ( $def->{type} eq 'string' ) {
                delete $def->{type};
                $types{ id2namespace( $raw->{id} . '.' . $name ) } = $def;

                #~ warn $name;
                #~ ddx $def;
                my @lines;
                say sprintf '    sub %s ($string) {', $name;
                say q[        { my $len = length $string; warn 'Expected ] .
                    $def->{maxLength} .
                    q[ chars max, found ' . $len if $len > ] .
                    $def->{maxLength} . ' };'
                    if defined $def->{maxLength};
                delete $def->{maxLength};
                say q[        { my $len = 0; while ($string =~ /\X/g) { $len++ } warn 'Expected ] .
                    $def->{maxGraphemes} .
                    q[ graphemes max, found ' . $len if $len > ] .
                    $def->{maxGraphemes} . ' };'
                    if defined $def->{maxGraphemes};
                delete $def->{maxGraphemes};
                say q/        warn 'Unknown value: '. $string unless grep { $string eq $_ } / . map { q['] . $_ . q['] }
                    @{ $def->{knownValues} } . ';'
                    if defined $def->{knownValues};
                delete $def->{knownValues};
                say '    }';

                if ( keys %$def ) {
                    die 'Unhandled string field';
                    ddx $def;
                    ...;
                }
            }
            elsif ( $def->{type} eq 'array' ) {
                $types{ id2namespace( $raw->{id} . '.' . $name ) } = $def;
                ddx $def;

                #~ ...;
            }
            elsif ( $def->{type} eq 'query' ) {
                my ( $pm, $pod );
                if ( $raw->{id} =~ m[app\.bsky] ) {
                    $pm  = $output{at_bsky_pm};
                    $pod = $output{at_bsky_pod};
                }
                elsif ( $raw->{id} =~ m[chat\.bsky] ) {
                    $pm  = $output{at_bsky_chat_pm};
                    $pod = $output{at_bsky_chat_pod};
                }
                elsif ( $raw->{id} =~ m[com\.atproto] ) {
                    $pm  = $output{at_pm};
                    $pod = $output{at_pod};
                }
                elsif ( $raw->{id} =~ m[tools\.ozone] ) {
                    $pm  = $output{at_ozone_pm};
                    $pod = $output{at_ozone_pod};
                }
                else {
                    ...;
                }
                $types{ id2namespace( $raw->{id} . '.' . $name ) } = $def;
                $name = $raw->{id} if $name eq 'main';
                warn $name;
                ddx $def;
                my @id = split /\./, $name;
                $pm->append_raw( sprintf "        method %s_%s (%s) {\n",
                    $id[-2], $id[-1], ( keys %{ $def->{parameters}{properties} } ? '%args' : '' ) );
                $pm->append_raw( q[            $self->http->session // confess 'requires an authenticated client';] . "\n" );
                $pm->append_raw( '# ' . $def->{parameters}{type} . "\n" ) if defined $def->{parameters}{type};

                if ( defined $def->{parameters}{properties} && defined $def->{parameters}{required} ) {
                    $pm->append_raw( sprintf qq[\$args{%s} // confess '%s is required';\n], $_, $_ ) for @{ $def->{parameters}{required} };
                }
                $pm->append_raw( sprintf q[ my $res = $self->http->get( sprintf( '%%s/xrpc/%%s', $self->host, '%s' )%s);],
                    $raw->{id}, keys %{ $def->{parameters}{properties} } ? ', { content => \%args } ' : '' );
                {
                    my $blah = Data::Dump::pp($def);
                    $blah =~ s/^/# /gm;
                    $pm->append_raw( $blah . "\n" );
                }
                $pm->append_raw("}\n");
                #
                $pod->append_raw( sprintf "=head2 C<%s_%s(%s)>\n\n", $id[-2], $id[-1], ( keys %{ $def->{parameters}{properties} } ? ' ... ' : ' ' ) );
                my $demo_code = demo_code( $id[-2] . '_' . $id[-1] );
                $demo_code = sprintf "\$at->%s_%s(%s);", $id[-2], $id[-1], ( keys %{ $def->{parameters}{properties} } ? ' ... ' : ' ' )
                    unless length $demo_code;
                $demo_code =~ s/^/    /gm;
                $pod->append_raw( $demo_code . "\n\n" );
                $pod->append_raw( sprintf "%s\n\n", $def->{description} ) if defined $def->{description};

                #~ {
                #~ my $blah = Data::Dump::pp($def);
                #~ $blah =~ s/^/# /gm;
                #~ for my $file ( $output{at_pod}, $output{at_pm} ) {
                #~ $file->append_raw("=begin raw\n\n");
                #~ $file->append_raw( "\n".$blah . "\n\n" );
                #~ $file->append_raw("=end raw\n\n");
                #~ }
                #~ }
                if ( keys %{ $def->{parameters}{properties} } ) {
                    $pod->append_raw("Expected parameters include:\n\n");
                    $pod->append_raw("=over\n\n");
                    for my $prop ( sort keys %{ $def->{parameters}{properties} } ) {
                        $pod->append_raw( sprintf "=item C<$prop>%s\n\n",
                            ( ( grep { $prop eq $_ } @{ $def->{parameters}{required} } ) ? ' - required' : '' ) );
                        $pod->append_raw( $def->{parameters}{properties}{$prop}{description} . "\n\n" )
                            if defined $def->{parameters}{properties}{$prop}{description};
                    }
                    $pod->append_raw("=back\n\n");
                }
                if ( defined $def->{errors} && @{ $def->{errors} } ) {
                    $pod->append_raw("Known errors:\n\n");
                    $pod->append_raw("=over\n\n");
                    for my $error ( @{ $def->{errors} } ) {
                        $pod->append_raw( sprintf "=item C<%s>\n\n", $error->{name} );
                        $pod->append_raw( $error->{description} . "\n\n" ) if defined $error->{description};
                    }
                    $pod->append_raw("=back\n\n");
                }

                #~ =head2 C<admin_deleteCommunicationTemplate( ... )>
                #~ $at->admin_deleteCommunicationTemplate( 99999 );
                #~ Delete a communication template.
                #~ Expected parameters include:
                #~ =over
                #~ =item C<id> - required
                #~ ID of the template.
                #~ =back
                #~ Returns a true value on success.
                #~ ...;
            }
            elsif ( $def->{type} eq 'record' ) {
                $types{ id2namespace( $raw->{id} . '.' . $name ) } = $def;

                #~ ...;
            }
            elsif ( $def->{type} eq 'procedure' ) {
                my ( $pm, $pod );
                if ( $raw->{id} =~ m[app\.bsky] ) {
                    $pm  = $output{at_bsky_pm};
                    $pod = $output{at_bsky_pod};
                }
                elsif ( $raw->{id} =~ m[chat\.bsky] ) {
                    $pm  = $output{at_bsky_chat_pm};
                    $pod = $output{at_bsky_chat_pod};
                }
                elsif ( $raw->{id} =~ m[com\.atproto] ) {
                    $pm  = $output{at_pm};
                    $pod = $output{at_pod};
                }
                elsif ( $raw->{id} =~ m[tools\.ozone] ) {
                    $pm  = $output{at_ozone_pm};
                    $pod = $output{at_ozone_pod};
                }
                else {
                    ...;
                }
                $types{ id2namespace( $raw->{id} . '.' . $name ) } = $def;
                $name = $raw->{id} if $name eq 'main';
                warn $name;
                ddx $def;
                my @id = split /\./, $name;
                $pm->append_raw( sprintf "        method %s_%s (%s) {\n",
                    $id[-2], $id[-1], ( keys %{ $def->{input}{schema}{properties} } ? '%args' : '' ) );
                $pm->append_raw( q[            $self->http->session // confess 'requires an authenticated client';] . "\n" )
                    unless $id[-2] . '_' . $id[-1] eq 'server_createSession';
                $pm->append_raw( '# ' . $def->{input}{schema}{type} . "\n" ) if defined $def->{input}{schema}{type};

                if ( defined $def->{input}{schema}{properties} && defined $def->{input}{schema}{required} ) {
                    $pm->append_raw( sprintf qq[\$args{%s} // confess '%s is required';\n], $_, $_ ) for @{ $def->{input}{schema}{required} };
                }
                $pm->append_raw( sprintf q[ my $res = $self->http->post( sprintf( '%%s/xrpc/%%s', $self->host, '%s' )%s);],
                    $raw->{id}, keys %{ $def->{input}{schema}{properties} } ? ', { content => \%args } ' : '' );
                {
                    my $blah = Data::Dump::pp($def);
                    $blah =~ s/^/# /gm;
                    $pm->append_raw( $blah . "\n" );
                }
                $pm->append_raw("}\n");
                #
                $pod->append_raw( sprintf "=head2 C<%s_%s(%s)>\n\n", $id[-2], $id[-1], ( $def->{parameters}{properties} ? ' ... ' : ' ' ) );
                my $demo_code = demo_code( $id[-2] . '_' . $id[-1] );
                $demo_code = sprintf "\$at->%s_%s(%s);", $id[-2], $id[-1], ( keys %{ $def->{parameters}{properties} } ? ' ... ' : ' ' )
                    unless length $demo_code;
                $demo_code =~ s/^/    /gm;
                $pod->append_raw( $demo_code . "\n\n" );
                $pod->append_raw( sprintf "%s\n\n", $def->{description} ) if defined $def->{description};

                #~ {
                #~ my $blah = Data::Dump::pp($def);
                #~ $blah =~ s/^/# /gm;
                #~ for my $file ( $pod, $output{at_pm} ) {
                #~ $file->append_raw("=begin raw\n\n");
                #~ $file->append_raw( "\n".$blah . "\n\n" );
                #~ $file->append_raw("=end raw\n\n");
                #~ }
                #~ }
                if ( $def->{input}{schema}{properties} ) {
                    $pod->append_raw("Expected parameters include:\n\n");
                    $pod->append_raw("=over\n\n");
                    for my $prop ( sort keys %{ $def->{input}{schema}{properties} } ) {
                        $pod->append_raw( sprintf "=item C<$prop>%s\n\n",
                            ( ( grep { $prop eq $_ } @{ $def->{input}{schema}{required} } ) ? ' - required' : '' ) );
                        $pod->append_raw( $def->{input}{schema}{properties}{$prop}{description} . "\n\n" )
                            if defined $def->{input}{schema}{properties}{$prop}{description};
                    }
                    $pod->append_raw("=back\n\n");
                }
                if ( defined $def->{errors} && @{ $def->{errors} } ) {
                    $pod->append_raw("Known errors:\n\n");
                    $pod->append_raw("=over\n\n");
                    for my $error ( @{ $def->{errors} } ) {
                        $pod->append_raw( sprintf "=item C<%s>\n\n", $error->{name} );
                        $pod->append_raw( $error->{description} . "\n\n" ) if defined $error->{description};
                    }
                    $pod->append_raw("=back\n\n");
                }

                #~ =head2 C<admin_deleteCommunicationTemplate( ... )>
                #~ $at->admin_deleteCommunicationTemplate( 99999 );
                #~ Delete a communication template.
                #~ Expected parameters include:
                #~ =over
                #~ =item C<id> - required
                #~ ID of the template.
                #~ =back
                #~ Returns a true value on success.
                #~ ...;
            }
            elsif ( $def->{type} eq 'token' ) {
                $types{ id2namespace( $raw->{id} . '.' . $name ) } = $def;

                #~ ...;
            }
            elsif ( $def->{type} eq 'subscription' ) {
                $types{ id2namespace( $raw->{id} . '.' . $name ) } = $def;

                #~ ...;
            }
            else {
                warn id2namespace( $raw->{id} . '.' . $name );
                ddx $def;
                die 'Unknown/unhandled type!';
                ...;
            }
        }

        #~ ddx $raw;
    },
    { recurse => 1 }
);

#~ ddx \%state;
END {
    #~ ddx \%types;
}

sub demo_code($method) {
    if ( $method eq 'actor_getProfiles' ) {
        return '$at->actor_getProfiles( ... );';
    }
}

sub footer($file) {
}
