package Genelet::Oauth2;

use strict;
use JSON;
use URI::Escape;
#use LWP::UserAgent;

# the followings for client request
sub oauth2_request {
  my $self = shift;
  my $method = shift;
  my $uri = shift;
  my $current = shift;

# my $ua = LWP::UserAgent->new();
  my $response;
  if ($method eq 'GET') {
    $uri .= '?';
    while (my ($key, $val) = each %$current) {
      $uri .= "$key=".uri_escape($val)."&";
    }
    substr($uri, -1, 1) = '';
    return $self->ua_get($uri);
  }

  return $self->ua_post($uri, $current);
}

sub oauth2_api {
  my $self = shift;
  my $back = shift;
  my $method = shift;
  my $uri = shift;
  my $current = shift;

  $current->{access_token} = $self->{ACCESS_TOKEN};
  my $body = $self->oauth2_request($method, $uri, $current);
  return 401 unless $body;

  my $parsed = decode_json($body);
  $back->{$_} = $parsed->{$_} for (keys %$parsed);

  return;
}

sub get_token {
  my $self = shift;
  my $body = shift;

  return decode_json($body);
}

1;
