requires 'perl', '5.036';
requires 'File::ShareDir::Tiny';

on 'test' => sub {
    requires 'Test2::V0';
};

