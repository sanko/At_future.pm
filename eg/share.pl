  use Path::Tiny qw[path];

my $atproto = path('../share')->absolute;
    if ( $atproto->is_dir ) {
        ( system("git -C $atproto pull") == 0 ) || system "git -C $atproto reset --hard origin/main";
    }
    else {
        system "git clone --depth 1 https://github.com/bluesky-social/atproto.git $atproto";
    }
