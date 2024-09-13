package At::UserAgent::Tiny 1.0 {
    use v5.38;
    use parent -norequire, 'At::UserAgent';
    use HTTP::Tiny;
    use JSON::Tiny qw[decode_json encode_json];
    use At::Error  qw[register];
    no warnings qw[experimental::builtin];
    #
    sub new ( $class, %args ) {
        bless {
            agent => $args{agent} // HTTP::Tiny->new(
                agent           => sprintf( 'At.pm/%1.2f; ', $At::VERSION ),
                default_headers => {
                    'Content-Type' => 'application/json',
                    Accept         => 'application/json',
                    ( $args{'language'} ? ( 'Accept-Language' => $args{'language'} ) : () )
                }
            ),
            ( defined $args{session} ? ( session => $args{session} ) : () )
        }, $class;
    }

    sub get ( $s, $url, $req //= {} ) {
        my $res
            = $s->{agent}
            ->get( $url . ( defined $req->{content} && keys %{ $req->{content} } ? '?' . $s->{agent}->www_form_urlencode( $req->{content} ) : '' ),
            { defined $req->{headers} ? ( headers => $req->{headers} ) : () } );
        if ( !$res->{success} ) {
            my $err = HTTPError( decode_json( $res->{content} )->{message} );
            return wantarray ? ( $err, $res->{headers} ) : $err;
        }
        $res->{content} = decode_json $res->{content} if $res->{content} && $res->{headers}{'content-type'} =~ m[application/json];

        #~ use Data::Dump;
        #~ ddx $res;
        wantarray ? ( $res->{content}, $res->{headers} ) : $res->{content};
    }

    sub post ( $s, $url, $req //= {} ) {
        my $res = $s->{agent}->post(
            $url,
            {   defined $req->{headers} ? ( headers => $req->{headers} )                                                               : (),
                defined $req->{content} ? ( content => ref $req->{content} eq 'HASH' ? encode_json $req->{content} : $req->{content} ) : ()
            }
        );
        if ( !$res->{success} ) {
            my $err = HTTPError( decode_json( $res->{content} )->{message} );
            return wantarray ? ( $err, $res->{headers} ) : $err;
        }
        $res->{content} = decode_json $res->{content} if $res->{content} && $res->{headers}{'content-type'} =~ m[application/json];

        #~ use Data::Dump;
        #~ ddx $res;
        wantarray ? ( $res->{content}, $res->{headers} ) : $res->{content};
    }
    sub websocket ( $s, $url, $req = () ) {...}

    sub _set_session ( $s, $session ) {
        $session || return;
        $s->{session} = $session;
        $s->_set_bearer_token( 'Bearer ' . $session->{accessJwt} );
    }

    sub session ($s) {
        $s->{session} // ();
    }

    sub _set_bearer_token ( $s, $token ) {
        $s->{agent}->{default_headers}{Authorization} = $token;
    }

    sub ratelimit($s) {
        $s->{ratelimit} // ();
    }
    register 'HTTPError';
}
1;
__END__
=encoding utf-8

=head1 NAME

At::UserAgent::Tiny - HTTP::Tiny-backed HTTP Client

=head1 SYNOPSIS

    use At; # It's the default. No need to do anything.

=head1 DESCRIPTION

This is the default HTTP client for L<At>. It's based on L<HTTP::Tiny>.

You shouldn't even need to think about this.

=head1 See Also

L<At::UserAgent> - utility base class

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
