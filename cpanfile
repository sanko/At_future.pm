requires 'perl', '5.038';
requires 'File::ShareDir::Tiny';
requires 'JSON::Tiny';
requires 'Path::Tiny';
requires 'Time::Moment';
requires 'URI';
requires 'Data::Dump';
requires 'IO::Socket::SSL' => '1.42';
requires 'Net::SSLeay'     => '1.49';
requires 'Mozilla::CA';
on 'test' => sub {
    requires 'Test2::V0';
};
