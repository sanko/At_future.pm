use Test2::V0 '!subtest';
use Test2::Util::Importer 'Test2::Tools::Subtest' => ( subtest_streamed => { -as => 'subtest' } );
use Test2::Plugin::UTF8;
use JSON::Tiny qw[decode_json];
use Path::Tiny qw[path];
use v5.36;

# Dev
# https://github.com/bluesky-social/atproto/blob/main/packages/api/tests/bsky-agent.test.ts
use Data::Dump;
use lib '../eg/', 'eg', '../lib', 'lib';
#
use if -d '../share',  At => -lexicons => '../share';
use if !-d '../share', At => ();

#~ use warnings 'At';
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
subtest live => sub {    # Public and totally worthless auth info
    my $login;
    my $path = path(__FILE__)->sibling('test_auth.json')->realpath;
    skip_all 'failed to locate auth data' unless $path->exists;
    my $auth = decode_json $path->slurp_utf8;
    subtest auth => sub {
        subtest resume => sub {
            skip_all 'no session to resume' unless keys %{ $auth->{resume} };
            my $todo = todo 'Working with live services here. Things might not go as we expect or hope...';
            ok $login = $bsky->resumeSession( %{ $auth->{resume} } ), 'resume session for the following tests';
        };
        subtest login => sub {
            skip_all 'resumed session; no login required' if keys %{ $auth->{resume} };
            my $todo = todo 'Working with live services here. Things might not go as we expect or hope...';
            ok $login = $bsky->login( %{ $auth->{login} } ), 'logging in for the following tests';
        };
    };

    # }
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
    SKIP: {
            $original // skip 'failed to get display name';
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
    {
        my $post;
        subtest 'post plain text content' => sub {
            $login || skip_all "$login";
            is $post = $bsky->post( text => 'Testing' ), hash {    # com.atproto.repo.createRecord#output
                field cid => D();                                  # CID
                field uri => D();                                  # AT-uri
                etc;                                               # might also contain commit and validationStatus
            }, 'post( ... )';
        };
        {
            my $like;
            subtest 'like the post we just created' => sub {
                $login || skip_all "$login";
                $post  || skip_all "$post";
                is $like = $bsky->like( $post->{uri}, $post->{cid} ), hash {

                    # com.atproto.repo.createRecord#output
                    field cid => D();    # CID
                    field uri => D();    # AT-uri
                    etc;                 # might also contain commit and validationStatus
                }, 'like(...)';
            };
            subtest 'delete like we just created' => sub {
                $login || skip_all "$login";
                $post  || skip_all "$post";
                $like  || skip_all "$like";
                is $bsky->deleteLike( $like->{uri} ), hash {
                    field commit => hash {
                        field cid => D();    # CID
                        field rev => D();
                        end;
                    };
                    etc;
                }, 'deleteLike(...)';
            };
        }
        {
            my $repost;
            subtest 'repost the post we just created' => sub {
                $login || skip_all "$login";
                $post  || skip_all "$post";
                is $repost = $bsky->repost( $post->{uri}, $post->{cid} ), hash {

                    # com.atproto.repo.createRecord#output
                    field cid => D();    # CID
                    field uri => D();    # AT-uri
                    etc;                 # might also contain commit and validationStatus
                }, 'repost(...)';
            };
            subtest 'delete repost we just created' => sub {
                $login  || skip_all "$login";
                $post   || skip_all "$post";
                $repost || skip_all "$repost";
                is $bsky->deleteRepost( $repost->{uri} ), hash {
                    field commit => hash {
                        field cid => D();    # CID
                        field rev => D();
                        end;
                    };
                    etc;
                }, 'deleteRepost(...)';
            };
        }
        subtest 'delete the post we created earlier' => sub {
            $login || skip_all "$login";
            $post  || skip_all "$post";
            is my $delete = $bsky->deletePost( $post->{uri} ), hash {
                field commit => hash {
                    field cid => D();    # CID
                    field rev => D();
                    end;
                };
                etc;
            }, 'deletePost(...)';
        };
    }
    subtest 'get our own follows' => sub {
        $login || skip_all "$login";
        is my $follows = $bsky->getFollows( $bsky->did ), hash {
            field cursor  => E();
            field follows => D();    # array of At::Lexicon::app::bsky::actor::defs::profileView objects
            field subject => D();    # profileview
            end;
        }, 'getFollows( ... )';
    };
    subtest 'get our own followers' => sub {
        $login || skip_all "$login";
        is my $followers = $bsky->getFollowers( $bsky->did ), hash {
            field cursor    => E();
            field followers => D();    # array of At::Lexicon::app::bsky::actor::defs::profileView objects
            field subject   => D();    # profileview
            end;
        }, 'getFollowers( ... )';
    };
    {
        my $follow;
        subtest 'follow myself' => sub {
            $login || skip_all "$login";
            is $follow = $bsky->follow( $bsky->did ), hash {
                field cid => D();
                field uri => D();
                etc;    # might also contain commit and validationStatus
            }, 'follow( ... )';
        };
        subtest 'delete the follow record we created earlier' => sub {
            $login  || skip_all "$login";
            $follow || skip_all "$follow";
            is my $delete = $bsky->deleteFollow( $follow->{uri} ), hash {
                field commit => hash {
                    field cid => D();    # CID
                    field rev => D();
                    end;
                };
                etc;
            }, 'deleteFollow(...)';
        };
    }
};
#
done_testing;
