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
subtest login => sub {
    ok $bsky->login(%auth), 'logging in for the following tests';
};
subtest 'client clones correctly after login' => sub {
    skip_all 'Clone is not installed' unless eval 'require Clone';
    isa_ok my $bsky2 = Clone::clone($bsky), ['At'], 'clone';
    is $bsky->{service}, $bsky2->{service}, 'services match';
    is $bsky->{session}, $bsky2->{session}, 'sessions match';
};
#
subtest 'upsertProfile correctly handles CAS failures' => sub {
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
    is my $timeline = $bsky->getTimeline(), hash {
        field cursor => D();
        field feed   => D();    # Feed items are subject to change
        end;
    }, 'getTimeline( )';
};
subtest 'pull author feed' => sub {
    is my $feed = $bsky->getAuthorFeed( actor => 'did:plc:z72i7hdynmk6r22z27h6tvur', filter => 'posts_and_author_threads', limit => 30 ), hash {
        field cursor => D();
        field feed   => D();    # Feed items are subject to change
        end;
    }, 'getAuthorFeed( ... )';
};
subtest 'pull post thread' => sub {
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

#~ my $likes = $at->getRepostedBy( uri => 'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2s5xxv2ze2c' );
#~ my $original = getProfileDisplayName($bsky);
#~ ok $bsky->upsertProfile(
#~ sub (%existing) {
#~ %existing, displayName => localtime . ' [' . ( int rand time ) . ']';
#~ }
#~ ),
#~ 'upsertProfile';
#~ #
#~ {
#~ my $todo = todo 'Bluesky might take a little time to commit changes';
#~ my $ok   = 0;
#~ for ( 1 .. 3 ) {
#~ last if $ok = $original ne getProfileDisplayName($bsky);
#~ diag 'giving Bluesky a moment to catch up...';
#~ sleep 2;
#~ }
#~ ok $ok, 'displayName has changed';
#~ }
#
done_testing;
