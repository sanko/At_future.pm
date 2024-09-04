requires 'perl', '5.036';
requires 'File::ShareDir::Tiny';
requires 'JSON::Tiny';
requires 'Path::Tiny';
requires 'Time::Moment';
requires 'URI';
requires 'Data::Dump';
on 'test' => sub {
    requires 'Test2::V0';
};
