requires 'Data::Dump';
requires 'File::ShareDir::Tiny';
requires 'IO::Socket::SSL', '1.42';
requires 'JSON::Tiny';
requires 'Mozilla::CA';
requires 'Net::SSLeay', '1.49';
requires 'Path::Tiny';
requires 'Time::Moment';
requires 'URI';
requires 'perl', 'v5.38.0';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
};

on test => sub {
    requires 'Test2::V0';
};

on develop => sub {
    requires 'Test::CPAN::Meta';
    requires 'Test::MinimumVersion::Fast', '0.04';
    requires 'Test::PAUSE::Permissions', '0.07';
    requires 'Test::Pod', '1.41';
    requires 'Test::Spellunker', 'v0.2.7';
};
