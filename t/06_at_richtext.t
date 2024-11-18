use Test2::V0 '!subtest';
use Test2::Util::Importer 'Test2::Tools::Subtest' => ( subtest_streamed => { -as => 'subtest' } );

#~ use Test2::Plugin::UTF8;
use v5.36;
use lib '../eg/', 'eg', '../lib', 'lib';
#
use if -d '../share',  At => -lexicons => '../share';
use if !-d '../share', At => ();
#
use At::RichText;
#
use Data::Dump;
my $rt = At::RichText->new;
ddx $rt;
$rt->tag( 'This is a rich messsage.', 'atproto' );
$rt->text(' This is plain text.');
$rt->link( ' link', 'https://www.google.com/' );
ddx $rt;
my $pp = At::Lexicon::app::bsky::feed::post->new(
%$rt
);
ddx $pp;
exit;
subtest 'calculates bytelength and grapheme length correctly' => sub {
    subtest 'Hello!' => sub {
        isa_ok my $rt = At::RichText->new( text => 'Hello!' ), ['At::RichText'];
        is $rt->length,         6, '->length';
        is $rt->graphemeLength, 6, '->graphemeLength';
    };
    subtest '👨‍👩‍👧‍👧' => sub {
        isa_ok my $rt = At::RichText->new( text => '👨‍👩‍👧‍👧' ), ['At::RichText'];
        is $rt->length,         25, '->length';
        is $rt->graphemeLength, 1,  '->graphemeLength';
    };
    subtest '👨‍👩‍👧‍👧🔥 good!✅' => sub {
        isa_ok my $rt = At::RichText->new( text => '👨‍👩‍👧‍👧🔥 good!✅' ), ['At::RichText'];
        is $rt->length,         38, '->length';
        is $rt->graphemeLength, 9,  '->graphemeLength';
    }
};
subtest insert => sub {
    subtest 'correctly adjusts facets (scenario A - before)' => sub {
        isa_ok my $input = At::RichText->new(
            text   => 'hello world',
            facets => [
                {   index    => { byteStart => 2, byteEnd => 7 },
                    features => [ { '$type' => 'app.bsky.richtext.facet#tag', tag => 'https://google.com/' } ]
                }
            ]
            ),
            ['At::RichText'];
        $input->insert( 0, 'test' );
        is $input->text,                          'testhello world', 'inserted';
        is $input->facets->[0]->index->byteStart, 6,                 'byteStart';
        is $input->facets->[0]->index->byteEnd,   11,                'byteEnd';
        is substr( $input->text, 6, 5 ),          'llo w',           'substr';
    };
    subtest 'correctly adjusts facets (scenario B - inner)' => sub {
        isa_ok my $input = At::RichText->new(
            text   => 'hello world',
            facets => [
                {   index    => { byteStart => 2, byteEnd => 7 },
                    features => [ { '$type' => 'app.bsky.richtext.facet#tag', tag => 'https://google.com/' } ]
                }
            ]
            ),
            ['At::RichText'];
        $input->insert( 4, 'test' );
        is $input->text,                          'helltesto world', 'inserted';
        is $input->facets->[0]->index->byteStart, 2,                 'byteStart';
        is $input->facets->[0]->index->byteEnd,   11,                'byteEnd';
        is substr( $input->text, 2, 9 ),          'lltesto w',       'substr';
    };
    subtest 'correctly adjusts facets (scenario C - after)' => sub {
        isa_ok my $input = At::RichText->new(
            text   => 'hello world',
            facets => [
                {   index    => { byteStart => 2, byteEnd => 7 },
                    features => [ { '$type' => 'app.bsky.richtext.facet#tag', tag => 'https://example.com/' } ]
                }
            ]
            ),
            ['At::RichText'];
        $input->insert( 8, 'test' );
        is $input->text,                          'hello wotestrld', 'inserted';
        is $input->facets->[0]->index->byteStart, 2,                 'byteStart';
        is $input->facets->[0]->index->byteEnd,   7,                 'byteEnd';
        is substr( $input->text, 2, 5 ),          'llo w',           'substr';
    };
};
#
subtest 'insert w/ fat unicode' => sub {
    my $input = sub() {
        At::RichText->new(
            text   => 'one👨‍👩‍👧‍👧 two👨‍👩‍👧‍👧 three👨‍👩‍👧‍👧',
            facets => [
                {   index    => { byteStart => 0, byteEnd => 28 },
                    features => [ { '$type' => 'app.bsky.richtext.facet#tag', tag => 'https://example.com/' } ]
                },
                {   index    => { byteStart => 29, byteEnd => 57 },
                    features => [ { '$type' => 'app.bsky.richtext.facet#tag', tag => 'https://example.com/' } ]
                },
                {   index    => { byteStart => 58, byteEnd => 88 },
                    features => [ { '$type' => 'app.bsky.richtext.facet#tag', tag => 'https://example.com/' } ]
                }
            ]
        );
    };
    subtest 'correctly adjusts facets (scenario A - before)' => sub {
        my $output = $input->();
        $output->insert( 0, 'test' );
        is $output->text, 'testone👨‍👩‍👧‍👧 two👨‍👩‍👧‍👧 three👨‍👩‍👧‍👧';
        diag 'pre ' . length 'one👨‍👩‍👧‍👧';
        {
            diag 'post' . length 'one👨‍👩‍👧‍👧';
            diag sprintf '%d, %d', $output->facets->[0]->index->byteStart,
                $output->facets->[0]->index->byteEnd - $output->facets->[0]->index->byteStart;
            is substr(
                $output->unicodeText(), $output->facets->[0]->index->byteStart, 10

                #~ $output->facets->[0]->index->byteEnd
                #~ -
                #~ $output->facets->[0]->index->byteStart
                ),
                'one👨‍👩‍👧‍👧', 'substr';
        }

        #~ is $input->facets->[0]->index->byteStart, 2,                 'byteStart';
        #~ is $input->facets->[0]->index->byteEnd,   7,                 'byteEnd';
    };

=cut
    const output = input.clone().insert(0, 'test')
    expect(output.text).toEqual('testone👨‍👩‍👧‍👧 two👨‍👩‍👧‍👧 three👨‍👩‍👧‍👧')
    expect(
      output.unicodeText.slice(
        output.facets?.[0].index.byteStart,
        output.facets?.[0].index.byteEnd,
      ),
    ).toEqual('one👨‍👩‍👧‍👧')
    expect(
      output.unicodeText.slice(
        output.facets?.[1].index.byteStart,
        output.facets?.[1].index.byteEnd,
      ),
    ).toEqual('two👨‍👩‍👧‍👧')
    expect(
      output.unicodeText.slice(
        output.facets?.[2].index.byteStart,
        output.facets?.[2].index.byteEnd,
      ),
    ).toEqual('three👨‍👩‍👧‍👧')
  })

  #~ it('correctly adjusts facets (scenario B - inner)', () => {
    #~ const output = input.clone().insert(3, 'test')
    #~ expect(output.text).toEqual('onetest👨‍👩‍👧‍👧 two👨‍👩‍👧‍👧 three👨‍👩‍👧‍👧')
    #~ expect(
      #~ output.unicodeText.slice(
        #~ output.facets?.[0].index.byteStart,
        #~ output.facets?.[0].index.byteEnd,
      #~ ),
    #~ ).toEqual('onetest👨‍👩‍👧‍👧')
    #~ expect(
      #~ output.unicodeText.slice(
        #~ output.facets?.[1].index.byteStart,
        #~ output.facets?.[1].index.byteEnd,
      #~ ),
    #~ ).toEqual('two👨‍👩‍👧‍👧')
    #~ expect(
      #~ output.unicodeText.slice(
        #~ output.facets?.[2].index.byteStart,
        #~ output.facets?.[2].index.byteEnd,
      #~ ),
    #~ ).toEqual('three👨‍👩‍👧‍👧')
  #~ })

  #~ it('correctly adjusts facets (scenario C - after)', () => {
    #~ const output = input.clone().insert(28, 'test')
    #~ expect(output.text).toEqual('one👨‍👩‍👧‍👧test two👨‍👩‍👧‍👧 three👨‍👩‍👧‍👧')
    #~ expect(
      #~ output.unicodeText.slice(
        #~ output.facets?.[0].index.byteStart,
        #~ output.facets?.[0].index.byteEnd,
      #~ ),
    #~ ).toEqual('one👨‍👩‍👧‍👧')
    #~ expect(
      #~ output.unicodeText.slice(
        #~ output.facets?.[1].index.byteStart,
        #~ output.facets?.[1].index.byteEnd,
      #~ ),
    #~ ).toEqual('two👨‍👩‍👧‍👧')
    #~ expect(
      #~ output.unicodeText.slice(
        #~ output.facets?.[2].index.byteStart,
        #~ output.facets?.[2].index.byteEnd,
      #~ ),
    #~ ).toEqual('three👨‍👩‍👧‍👧')
  #~ })
#~ })
=cut

};

done_testing;
exit;
#
subtest delete => sub {
    my $input = sub () {
        isa_ok my $ret = At::RichText->new(
            text   => 'hello world',
            facets => [
                {   index    => { byteStart => 2, byteEnd => 7 },
                    features => [ { '$type' => 'app.bsky.richtext.facet#tag', tag => 'https://example.com/' } ]
                }
            ]
            ),
            ['At::RichText'];
        $ret;
    };
    subtest 'correctly adjusts facets (scenario A - entirely outer)' => sub {
        my $output = $input->()->delete( 0, 9 );
        is $output->text,   'ld', '->text';
        is $output->facets, [],   '->facets';
    };
    subtest 'correctly adjusts facets (scenario B - entirely after)' => sub {
        my $output = $input->()->delete( 7, 11 );
        is $output->text,                          'hello w', '->text';
        is $output->facets->[0]->index->byteStart, 2,         '->byteStart';
        is $output->facets->[0]->index->byteEnd,   7,         '->byteEnd';
    };
    subtest 'correctly adjusts facets (scenario C - partially after)' => sub {
        my $output = $input->()->delete( 4, 11 );
        is $output->text,                          'hell', '->text';
        is $output->facets->[0]->index->byteStart, 2,      '->byteStart';
        is $output->facets->[0]->index->byteEnd,   4,      '->byteEnd';
    };
    subtest 'correctly adjusts facets (scenario D - entirely inner)' => sub {
        my $output = $input->()->delete( 3, 5 );
        is $output->text,                          'hel world', '->text';
        is $output->facets->[0]->index->byteStart, 2,           '->byteStart';
        is $output->facets->[0]->index->byteEnd,   5,           '->byteEnd';
    };
    subtest 'correctly adjusts facets (scenario E - partially before)' => sub {
        my $output = $input->()->delete( 1, 5 );
        is $output->text,                          'h world', '->text';
        is $output->facets->[0]->index->byteStart, 1,         '->byteStart';
        is $output->facets->[0]->index->byteEnd,   3,         '->byteEnd';
    };
    subtest 'correctly adjusts facets (scenario F - entirely before)' => sub {
        my $output = $input->()->delete( 0, 2 );
        is $output->text,                          'llo world', '->text';
        is $output->facets->[0]->index->byteStart, 0,           '->byteStart';
        is $output->facets->[0]->index->byteEnd,   5,           '->byteEnd';
    };
};
#
done_testing;
