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
subtest 'should retrieve the api app' => sub {
    isa_ok my $bsky = At->new( service => 'https://bsky.social' ), ['At'];
};
subtest 'clones correctly' => sub {
    skip_all 'Clone is not installed' unless eval 'require Clone';
    isa_ok my $bsky1 = At->new( service => 'https://bsky.social' ), ['At'], 'original';
    isa_ok my $bsky2 = Clone::clone($bsky1),                        ['At'], 'clone';
    is $bsky1->{service}, $bsky2->{service}, 'services match';
};

sub getProfileDisplayName ($at) {
    $at->getProfile( actor => $at->did, rkey => 'self' )->{displayName} // ();
}
subtest 'upsertProfile correctly handles CAS failures' => sub {
    isa_ok my $bsky = At->new( service => 'https://bsky.social' ), ['At'];
    $bsky->login(%auth);
    my $original = getProfileDisplayName($bsky);
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
            last if $ok = $original ne getProfileDisplayName($bsky);
            diag 'giving Bluesky a moment to catch up...';
            sleep 2;
        }
        ok $ok, 'displayName has changed';
    }
};
#
done_testing;
