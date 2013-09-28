use strict;
use warnings;
use Test::More tests => 6;
use Test::Warnings 0.010 qw(:all :no_end_test);
use t::lib::FakeResponse;

BEGIN { use_ok('Regru::API::Response') }

my $serializer;

subtest 'Generic behaviour' => sub {
    plan tests => 5;

    my @attributes = qw(
        error_code
        error_text
        error_params
        is_success
        is_service_fail
        answer
        response
    );

    my @methods = qw(
        get
        _trigger_response
    );

    my $resp = new_ok 'Regru::API::Response';

    # cache serializer
    $serializer ||= $resp->serializer;

    can_ok $resp, @attributes;
    can_ok $resp, @methods;

    ok $resp->does('Regru::API::Role::Serializer'),     'Instance does the Serializer role';

    # applied by roles
    can_ok $resp, qw(serializer);
};

subtest 'Expected response case (success)' => sub {
    plan tests => 6;

    ok $serializer, 'Serializer available';

    my $sample = {
        answer => {
            user_id => 0,
            login => 'test',
        },
        result => 'success',
    };

    my $fake = t::lib::FakeResponse->compose(200, $serializer->encode($sample));

    my $resp = new_ok 'Regru::API::Response' =>[( response => $fake )];

    ok          $resp->is_success,                              'Response okay';
    is_deeply   $resp->answer,          $sample->{answer},      'Got expected answer';
    is          $resp->get('login'),    'test',                 'Field login as expected';
    cmp_ok      $resp->get('user_id'),  '==',   0,              'Field user_id as expected';
};

subtest 'Invalid response case' => sub {
    plan tests => 5;

    ok $serializer, 'Serializer available';

    my $resp = new_ok 'Regru::API::Response';

    my $warned = warning { $resp->response($serializer) };

    like $warned, qr/^Error: Invalid response/,                 'Warns on invalid response';
    is $resp->error_code, 'API_FAIL',                           '...with correct error code';
    is $resp->error_text, 'API response error',                 '...with correct error text';
};

subtest 'Invalid JSON content case' => sub {
    plan tests => 6;

    ok $serializer, 'Serializer available';

    my $resp = new_ok 'Regru::API::Response';

    my $fake = sub { t::lib::FakeResponse->compose(200, $_[0]) };

    my $warned = warning { $resp->response($fake->("There’s More Than One Way To Do It")) };
    like $warned, qr/^Error: malformed JSON string.*/,          'Warns on invalid response content';
    is $resp->error_code, 'API_FAIL',                           '...with correct error code';
    is $resp->error_text, 'API response error',                 '...with correct error text';

    $warned = warning { $resp->response($fake->("['a','b']")) };
    like $warned, qr/^Error: malformed JSON string.*/,          'Warns on invalid response content again';
};

subtest 'Expected response case (failed)' => sub {
    plan tests => 6;

    ok $serializer, 'Serializer available';

    my $resp = new_ok 'Regru::API::Response';

    my $sample = {
        error_text => 'Username/password Incorrect',
        error_code => 'PASSWORD_AUTH_FAILED',
        result     => 'error'
    };

    my $fake = t::lib::FakeResponse->compose(200, $serializer->encode($sample));

    $resp->response($fake);

    ok          !$resp->is_success,                                 'API request okay but unsuccessful';
    is_deeply   $resp->answer,      {},                             'Got empty answer';
    is          $resp->error_code,  'PASSWORD_AUTH_FAILED',         '...with correct error code';
    is          $resp->error_text,  'Username/password Incorrect',  '...with correct error code';
};

1;