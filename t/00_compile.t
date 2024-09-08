use Test2::V0;
use v5.36;

# Dev
# https://github.com/bluesky-social/atproto/blob/main/packages/api/tests/bsky-agent.test.ts
use Data::Dump;
use lib '../eg/', 'eg', '../lib', 'lib';

# Public and totally worthless
my %auth = ( identifier => 'atperl.bsky.social', password => 'ck2f-bqxl-h54l-xm3l' );
#
use if -d '../share',  At => -lexicons => '../share';
use if !-d '../share', At => ();
#
my $bsky;

# Utils
sub getProfileDisplayName () {
    $bsky->getProfile( actor => $bsky->did, rkey => 'self' )->{displayName} // ();
}
subtest core => sub {
    subtest 'verify object' => sub {
        my $todo      = todo 'verify() does not work yet';
        my $fake_post = At::Lexicon::app::bsky::feed::post->new( test => 'this' );
        ok $fake_post->verify(), 'verify';
    };
    subtest 'verify token generation' => sub {
        is At::Lexicon::com::atproto::moderation::defs::reasonSpam(), 'com.atproto.moderation.defs#reasonSpam',
            'At::Lexicon::com::atproto::moderation::defs::reasonSpam()';
        is At::Lexicon::com::atproto::moderation::defs::reasonViolation(), 'com.atproto.moderation.defs#reasonViolation',
            'At::Lexicon::com::atproto::moderation::defs::reasonViolation()';
    };
};

#~ exit;
#
subtest 'should build the client' => sub {
    isa_ok $bsky = At->new( service => 'https://bsky.social' ), ['At'];
};
subtest 'client clones correctly' => sub {
    skip_all 'Clone is not installed' unless eval 'require Clone';
    isa_ok my $bsky1 = At->new( service => 'https://bsky.social' ), ['At'], 'original';
    isa_ok my $bsky2 = Clone::clone($bsky1),                        ['At'], 'clone';
    is $bsky1->{service}, $bsky2->{service}, 'services match';
    is $bsky->{session},  $bsky2->{session}, 'sessions match';
};
#
SKIP: {
    my $login;
    subtest login => sub {
        my $todo = todo 'Working with live services here. Things might not go as we expect or hope...';
        ok $login = $bsky->login(%auth), 'logging in for the following tests';
    };
    #
    subtest 'client clones correctly after login' => sub {
        $login || skip_all "$login";
        skip_all 'Clone is not installed' unless eval 'require Clone';
        isa_ok my $bsky2 = Clone::clone($bsky), ['At'], 'clone';
        is $bsky->{service}, $bsky2->{service}, 'services match';
        is $bsky->{session}, $bsky2->{session}, 'sessions match';
    };
    #
    subtest 'upsertProfile correctly handles CAS failures' => sub {
        $login || skip_all "$login";
        my $original = getProfileDisplayName();
        ok $bsky->upsertProfile(
            sub (%existing) {
                %existing, displayName => localtime . ' [' . ( int rand time ) . ']';
            }
            ),
            'upsertProfile';
        #
        {
            my $todo = todo 'Bluesky might take a little time to commit changes';
            my $ok   = 0;
            for ( 1 .. 3 ) {
                last if $ok = $original ne getProfileDisplayName();
                diag 'giving Bluesky a moment to catch up...';
                sleep 2;
            }
            ok $ok, 'displayName has changed';
        }
    };
    subtest 'pull timeline' => sub {
        $login || skip_all "$login";
        is my $timeline = $bsky->getTimeline(), hash {
            field cursor => D();
            field feed   => D();    # Feed items are subject to change
            end;
        }, 'getTimeline( )';
    };
    subtest 'pull author feed' => sub {
        $login || skip_all "$login";
        is my $feed = $bsky->getAuthorFeed( actor => 'did:plc:z72i7hdynmk6r22z27h6tvur', filter => 'posts_and_author_threads', limit => 30 ), hash {
            field cursor => D();
            field feed   => D();    # Feed items are subject to change
            end;
        }, 'getAuthorFeed( ... )';
    };
    subtest 'pull post thread' => sub {
        $login || skip_all "$login";
        is my $thread = $bsky->getPostThread( uri => 'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c' ), hash {
            field threadgate => E();
            field thread     => meta {    # Feed items are subject to change
                prop isa     => 'At::Lexicon::app::bsky::feed::defs::threadViewPost';
                prop reftype => 'HASH';
            };
            end;
        }, 'getPostThread( ... )';
    };
    subtest 'pull post' => sub {
        $login || skip_all "$login";
        is my $post = $bsky->getPost('at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c'), hash {
            field posts => array {
                item meta {
                    prop blessed => 'At::Lexicon::app::bsky::feed::defs::postView'
                };
                end;
            };
            end;
        }, 'getPost( ... )';
    };
    subtest 'pull reposts' => sub {
        $login || skip_all "$login";
        is my $reposts = $bsky->getRepostedBy( uri => 'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c' ), hash {
            field cursor     => D();
            field cid        => E();
            field repostedBy => D();    # array
            field uri        => D();    # AT-uri
            end;
        }, 'getRepostedBy( ... )';
    };
}
#
done_testing;
