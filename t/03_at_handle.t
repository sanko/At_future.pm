use Test2::V0;
use v5.36;
use lib '../eg/', 'eg', '../lib', 'lib';
#
use if -d '../share',  At => -lexicons => '../share';
use if !-d '../share', At => ();
#
# Invalid syntax:
subtest 'malformed handle' => sub {
    like( dies { At::Protocol::Handle->new($_) }, qr/malformed handle/, $_ ) for qw[
        jo@hn.test
        💩.test
        john..test
        xn--bcher-.tld
        john.0
        cn.8
        www.masełkowski.pl.com
        org
        name.org.];
};

# Valid syntax, but must always fail resolution due to other restrictions:
subtest 'fatal level restricted TDL' => sub {
    like( dies { At::Protocol::Handle->new($_) }, qr/disallowed TLD in handle/, $_ ) for qw[
        2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion
        laptop.local
        blah.arpa];
};

# Valid but only during testing and development
subtest 'warning level restricted TDL' => sub {    # Note: only thrown once!
    like( warning { At::Protocol::Handle->new($_) }, qr/testing TLD used in handle/, $_ ) for qw[
        nice.test];
};

# All examples are taken directly from the DID docs found at https://atproto.com/specs/handle#identifier-examples
# Syntactically valid handles (which may or may not have existing TLDs):
ok( At::Protocol::Handle->new('jay.bsky.social'),                              'jay.bsky.social' );
ok( At::Protocol::Handle->new('8.cn'),                                         '8.cn' );
ok( At::Protocol::Handle->new('name.t--t'),                                    'name.t--t' );             #  not a real TLD, but syntax ok
ok( At::Protocol::Handle->new('XX.LCS.MIT.EDU'),                               'XX.LCS.MIT.EDU' );
ok( At::Protocol::Handle->new('a.co'),                                         'a.co' );
ok( At::Protocol::Handle->new('xn--notarealidn.com'),                          'xn--notarealidn.com' );
ok( At::Protocol::Handle->new('xn--fiqa61au8b7zsevnm8ak20mc4a87e.xn--fiqs8s'), 'xn--fiqa61au8b7zsevnm8ak20mc4a87e.xn--fiqs8s' );
ok( At::Protocol::Handle->new('xn--ls8h.test'),                                'xn--ls8h.test' );
ok( At::Protocol::Handle->new('example.t'),                                    'example.t' );             # not a real TLD, but syntax ok
#
#
done_testing;
