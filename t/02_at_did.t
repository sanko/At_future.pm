use Test2::V0;
use v5.36;
use lib '../eg/', 'eg', '../lib', 'lib';
#
use if -d '../share',  At => -lexicons => '../share';
use if !-d '../share', At => ();
#
# All examples are taken directly from the DID docs found at https://atproto.com/specs/did#examples
# Valid DIDs for use in atproto (correct syntax, and supported method):
ok( At::Protocol::DID->new('did:plc:z72i7hdynmk6r22z27h6tvur'), 'did:plc:z72i7hdynmk6r22z27h6tvur' );
ok( At::Protocol::DID->new('did:web:blueskyweb.xyz'),           'did:web:blueskyweb.xyz' );

# Valid DID syntax (would pass Lexicon syntax validation), but unsupported DID method:
subtest 'unsupported method' => sub {
    like( warning { At::Protocol::DID->new($_) }, qr/unsupported method/, $_ ) for qw[
        did:method:val:two
        did:m:v
        did:method::::val
        did:method:-:_:.
        did:key:zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn6N
    ];
};

# Invalid DID identifier syntax (regardless of DID method):
subtest 'malformed DID' => sub {
    like( dies { At::Protocol::DID->new($_) }, qr/malformed DID/, $_ ) for qw[did:METHOD:val
        did:m123:val
        DID:method:val
        did:method:
        did:method:val/two
        did:method:val?two], 'did:method:val#two';
};
#
done_testing;
