use Test2::V0;
use v5.36;

# Dev
# https://github.com/bluesky-social/atproto/blob/main/packages/api/tests/bsky-agent.test.ts
use Data::Dump;
use lib '../eg/', 'eg', '../lib', 'lib';

# Public and totally worthless
my %auth = ( identifier => 'atperl.bsky.social', password => 'ck2f-bqxl-h54l-xm3l' );
#
use At;
#
subtest 'should retrieve the api app' => sub {
    isa_ok my $agent = At->new( service => 'https://bsky.social' ), ['At'];
};
subtest 'clones correctly' => sub {
    skip_all 'Clone is not installed' unless eval 'require Clone';
    isa_ok my $agent1 = At->new( service => 'https://bsky.social' ), ['At'], 'original';
    isa_ok my $agent2 = Clone::clone($agent1),                       ['At'], 'clone';
    is $agent1->{service}, $agent2->{service}, 'services match';
};

sub getProfileDisplayName ($at) {
    $at->getProfile( actor => $at->did, rkey => 'self' )->{displayName} // ();
}
subtest 'upsertProfile correctly handles CAS failures' => sub {
    isa_ok my $agent = At->new( service => 'https://bsky.social' ), ['At'];
    $agent->login(%auth);
    my $original = getProfileDisplayName($agent);
    ok $agent->upsertProfile(
        sub (%existing) {
            %existing, displayName => localtime . ' [' . ( int rand time ) . ']';
        }
        ),
        'upsertProfile';
    isnt $original, getProfileDisplayName($agent), 'displayName has changed';
};
#
done_testing;
