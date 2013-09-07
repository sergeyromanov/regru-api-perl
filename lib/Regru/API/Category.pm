package Regru::API::Category;
# Нужно переименовать в Regru::API::Handler
use Modern::Perl;
use Data::Dumper;

use Moo;
use URI::Encode 'uri_encode';
use List::MoreUtils 'any';
use Carp;
use Regru::API::Response;

has 'methods' => (is => 'ro');
has 'namespace' => ( is => 'ro', default => sub { q{} });
has ['username', 'password', 'io_encoding', 'lang', 'debug'] => ( is => 'ro');

my $api_url = "https://api.reg.ru/api/regru2/";

=head1 NAME

    Regru::API::Category - parent handler for all categories handlers.

=cut
use vars '$AUTOLOAD';


sub AUTOLOAD {
    my $self = shift;

    my $namespace = $self->namespace;

    # сделать запрос к АПИ
    my $called_method = $AUTOLOAD;
    $called_method =~ s/^.*:://;

    if (any { $_ eq $called_method } @{$self->methods}) {
        return $self->_api_call($namespace => $called_method, @_);
    }
    else {
        croak "API call $called_method is undefined.";
    }
}

sub DESTROY {};


sub _debug_log {
    my $self = shift;
    my $message = shift;

    confess $message if $self->debug;
}


sub _api_call {
    my $self = shift;
    my $namespace = shift;
    my $method = shift;
    my %params = @_;

    $self->_debug_log("API call: $namespace/$method, params: ".Dumper(%params));

    my $ua = $self->_get_ua;
    my $url = $api_url . $namespace;
    $url .= '/' if $namespace;
    $url .= $method . '?';
    $params{ username } = $self->username;
    $params{ password } = $self->password;
    $params{ output_format } = 'json';
    for my $param_name (keys %params) {
        my $value = uri_encode($param_name);
        $url .= '&' . $param_name . '=' . $value;
    }
    my $response = $ua->get($url);
    if ($response->is_success) {
        my $raw_content = $response->decoded_content;
        my $api_response = Regru::API::Response->new(raw_content => $raw_content);
        return $api_response;
    }
    else {
        die Dumper $response;
        croak "Not implemented yet.";
    }
}


sub _get_ua {
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    return $ua;
}


1;