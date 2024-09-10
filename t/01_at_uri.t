use Test2::V0;
use v5.36;

# Dev
# https://github.com/bluesky-social/atproto/blob/main/packages/api/tests/bsky-agent.test.ts
use Data::Dump;
use lib '../eg/', 'eg', '../lib', 'lib';
#
use if -d '../share',  At => -lexicons => '../share';
use if !-d '../share', At => ();
#
subtest 'At::URI::_query' => sub {
    isa_ok my $query = At::URI::_query->new('?foo=bar&foo=baz'), ['At::URI::_query'], '?foo=bar&foo=baz';
    is $query->as_string, 'foo=bar&foo=baz', '->as_string';
    ok $query->add_param( foo => 'qux' ), q[add_param(foo => 'qux')];
    is $query->as_string, 'foo=bar&foo=baz&foo=qux', '->as_string';
    ok $query->set_param( foo => 'corge' ), q[set_param(foo => 'corge')];
    is $query->as_string, 'foo=corge&foo=baz&foo=qux', '->as_string';
    ok $query->set_param( foo => qw[grault garply waldo fred] ), q[set_param(foo => [...])];
    is $query->as_string,            'foo=grault&foo=garply&foo=waldo&foo=fred', '->as_string';
    is [ $query->get_param('foo') ], [qw[grault garply waldo fred]],             '->get_param("foo")';
    ok $query->replace_param( foo => 'test' ), q[replace_param(foo => [...])];
    ok $query->reset,                          '->reset';
    is [ $query->get_param('foo') ], [], '->get_param("foo")';
    is $query->as_string,            '', '->as_string';
    ok $query->set_param( foo => 'plugh' ), q[set_param(foo => 'plugh')];
    ok $query->set_param( bar => 'xyzzy' ), q[set_param(bar => 'xyzzy')];
    is $query->as_string, 'foo=plugh&bar=xyzzy', '->as_string';
    ok $query->add_param( foo => 'thud' ), q[add_param(foo => 'thud')];
    is $query->as_string, 'foo=plugh&bar=xyzzy&foo=thud', '->as_string';
    ok $query->delete_param('foo'), q[delete_param('foo')];
    is $query->as_string, 'bar=xyzzy', '->as_string';
};
subtest 'parses valid at uris' => sub {
    my @uris = (

        # Taken from https://github.com/bluesky-social/atproto/blob/main/packages/syntax/tests/aturi.test.ts
        # [ input, host, path, query, hash]
        [ 'foo.com',                                                    'foo.com', '',         '',                 '' ],
        [ 'at://foo.com',                                               'foo.com', '',         '',                 '' ],
        [ 'at://foo.com/',                                              'foo.com', '/',        '',                 '' ],
        [ 'at://foo.com/foo',                                           'foo.com', '/foo',     '',                 '' ],
        [ 'at://foo.com/foo/',                                          'foo.com', '/foo/',    '',                 '' ],
        [ 'at://foo.com/foo/bar',                                       'foo.com', '/foo/bar', '',                 '' ],
        [ 'at://foo.com?foo=bar',                                       'foo.com', '',         'foo=bar',          '' ],
        [ 'at://foo.com?foo=bar&baz=buux',                              'foo.com', '',         'foo=bar&baz=buux', '' ],
        [ 'at://foo.com/?foo=bar',                                      'foo.com', '/',        'foo=bar',          '' ],
        [ 'at://foo.com/foo?foo=bar',                                   'foo.com', '/foo',     'foo=bar',          '' ],
        [ 'at://foo.com/foo/?foo=bar',                                  'foo.com', '/foo/',    'foo=bar',          '' ],
        [ 'at://foo.com#hash',                                          'foo.com', '',         '',                 '#hash' ],
        [ 'at://foo.com/#hash',                                         'foo.com', '/',        '',                 '#hash' ],
        [ 'at://foo.com/foo#hash',                                      'foo.com', '/foo',     '',                 '#hash' ],
        [ 'at://foo.com/foo/#hash',                                     'foo.com', '/foo/',    '',                 '#hash' ],
        [ 'at://foo.com?foo=bar#hash',                                  'foo.com', '',         'foo=bar',          '#hash' ],
        [ 'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw', 'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw', '', '', '', ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '', '', '',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw/',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '/', '', '',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw/foo',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '/foo', '', '',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw/foo/',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '/foo/', '', '',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw/foo/bar',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '/foo/bar', '', '',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw?foo=bar',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '', 'foo=bar', '',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw?foo=bar&baz=buux',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '', 'foo=bar&baz=buux', '',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw/?foo=bar',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '/', 'foo=bar', '',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw/foo?foo=bar',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '/foo', 'foo=bar', '',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw/foo/?foo=bar',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '/foo/', 'foo=bar', '',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw#hash',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '', '', '#hash',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw/#hash',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '/', '', '#hash',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw/foo#hash',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '/foo', '', '#hash',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw/foo/#hash',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '/foo/', '', '#hash',
        ],
        [   'at://did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw?foo=bar#hash',
            'did:example:EiAnKD8-jfdd0MDcZUjAbRgaThBrMxPTFOxcnfJhI7Ukaw',
            '', 'foo=bar', '#hash',
        ],
        [ 'did:web:localhost%3A1234',                                   'did:web:localhost%3A1234', '',         '',                 '' ],
        [ 'at://did:web:localhost%3A1234',                              'did:web:localhost%3A1234', '',         '',                 '' ],
        [ 'at://did:web:localhost%3A1234/',                             'did:web:localhost%3A1234', '/',        '',                 '', ],
        [ 'at://did:web:localhost%3A1234/foo',                          'did:web:localhost%3A1234', '/foo',     '',                 '', ],
        [ 'at://did:web:localhost%3A1234/foo/',                         'did:web:localhost%3A1234', '/foo/',    '',                 '', ],
        [ 'at://did:web:localhost%3A1234/foo/bar',                      'did:web:localhost%3A1234', '/foo/bar', '',                 '', ],
        [ 'at://did:web:localhost%3A1234?foo=bar',                      'did:web:localhost%3A1234', '',         'foo=bar',          '', ],
        [ 'at://did:web:localhost%3A1234?foo=bar&baz=buux',             'did:web:localhost%3A1234', '',         'foo=bar&baz=buux', '', ],
        [ 'at://did:web:localhost%3A1234/?foo=bar',                     'did:web:localhost%3A1234', '/',        'foo=bar',          '', ],
        [ 'at://did:web:localhost%3A1234/foo?foo=bar',                  'did:web:localhost%3A1234', '/foo',     'foo=bar',          '', ],
        [ 'at://did:web:localhost%3A1234/foo/?foo=bar',                 'did:web:localhost%3A1234', '/foo/',    'foo=bar',          '', ],
        [ 'at://did:web:localhost%3A1234#hash',                         'did:web:localhost%3A1234', '',         '',                 '#hash', ],
        [ 'at://did:web:localhost%3A1234/#hash',                        'did:web:localhost%3A1234', '/',        '',                 '#hash', ],
        [ 'at://did:web:localhost%3A1234/foo#hash',                     'did:web:localhost%3A1234', '/foo',     '',                 '#hash', ],
        [ 'at://did:web:localhost%3A1234/foo/#hash',                    'did:web:localhost%3A1234', '/foo/',    '',                 '#hash', ],
        [ 'at://did:web:localhost%3A1234?foo=bar#hash',                 'did:web:localhost%3A1234', '',         'foo=bar',          '#hash', ],
        [ 'at://4513echo.bsky.social/app.bsky.feed.post/3jsrpdyf6ss23', '4513echo.bsky.social',     '/app.bsky.feed.post/3jsrpdyf6ss23', '', '', ],
    );
    #
    for my $uri (@uris) {
        subtest $uri->[0] => sub {
            isa_ok my $urip = At::URI->new( $uri->[0] ), ['At::URI'], 'At::URI->new(...)';
            is $urip->protocol,     'at:',               '->protocol';
            is $urip->host,         $uri->[1],           '->host';
            is $urip->origin,       'at://' . $uri->[1], '->origin';
            is $urip->pathname,     $uri->[2],           '->pathname';
            is $urip->search // '', $uri->[3],           '->search';
            is $urip->hash,         $uri->[4],           '->hash';
        }
    }
};
subtest 'handles ATP-specific parsing' => sub {
    subtest 'at://foo.com' => sub {
        isa_ok my $urip = At::URI->new('at://foo.com'), ['At::URI'], 'At::URI->new(...)';
        is $urip->collection, '', '->collection';
        is $urip->rkey,       '', '->rkey';
    };
    subtest 'at://foo.com/com.example.foo' => sub {
        isa_ok my $urip = At::URI->new('at://foo.com/com.example.foo'), ['At::URI'], 'At::URI->new(...)';
        is $urip->collection, 'com.example.foo', '->collection';
        is $urip->rkey,       '',                '->rkey';
    };
    subtest 'at://foo.com/com.example.foo/123' => sub {
        isa_ok my $urip = At::URI->new('at://foo.com/com.example.foo/123'), ['At::URI'], 'At::URI->new(...)';
        is $urip->collection, 'com.example.foo', '->collection';
        is $urip->rkey,       '123',             '->rkey';
    };
};
subtest 'supports modifications' => sub {
    isa_ok my $urip = At::URI->new('at://foo.com'), ['At::URI'], 'At::URI->new(...)';
    is $urip, 'at://foo.com/', 'foo.com';
    #
    subtest 'host' => sub {
        $urip->host('bar.com');
        is $urip, 'at://bar.com/', 'bar.com';
        $urip->host('did:web:localhost%3A1234');
        is $urip, 'at://did:web:localhost%3A1234/', 'did:web:localhost%3A1234';
        $urip->host('foo.com');    # restore
    };
    subtest 'pathname' => sub {
        $urip->pathname('/');
        is $urip, 'at://foo.com/', '/';
        $urip->pathname('/foo');
        is $urip, 'at://foo.com/foo', '/foo';
        $urip->pathname('foo');
        is $urip, 'at://foo.com/foo', 'foo';
    };
    subtest 'collection and rkey' => sub {
        $urip->collection('com.example.foo');
        $urip->rkey('123');
        is $urip, 'at://foo.com/com.example.foo/123', 'collection: com.example.foo, rkey: 123';
        $urip->rkey('124');
        is $urip, 'at://foo.com/com.example.foo/124', 'collection: com.example.foo, rkey: 124';
        $urip->collection('com.other.foo');
        is $urip, 'at://foo.com/com.other.foo/124', 'collection: com.other.foo, rkey: 124';
        $urip->pathname('');
        $urip->rkey('123');
        is $urip, 'at://foo.com/undefined/123', 'pathname: [empty string], rkey: 123';
        $urip->pathname('foo');    # restore
    };
    subtest 'search' => sub {
        $urip->search('?foo=bar');
        is $urip, 'at://foo.com/foo?foo=bar', 'search: ?foo=bar';
        $urip->search->set_param( baz => 'buux' );
        is $urip, 'at://foo.com/foo?foo=bar&baz=buux', 'search: ?foo=bar&baz=buux';
    };
    subtest 'hash' => sub {
        $urip->hash('#hash');
        is $urip, 'at://foo.com/foo?foo=bar&baz=buux#hash', 'hash: #hash';
        $urip->hash('hash');
        is $urip, 'at://foo.com/foo?foo=bar&baz=buux#hash', 'hash: hash';
    };
};
#
done_testing;
