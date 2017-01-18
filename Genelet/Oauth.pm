package Genelet::Oauth;
# interface

use strict;
use JSON;
use URI::Escape;
use LWP::UserAgent;

sub oauth_header_get {
  my $self = shift;
  my $hash = shift;

  return 1051 unless $self->is_oauth();

  my @pairs = split /\s*\,\s*/, $1, -1;
  foreach my $pair (@pairs) {
    my ($key, $val) = split '=', $pair, 2;
    if ($val =~ /^"(.*)"$/) {
      $val = $1;
    } else {
      return 1052;
    }
    if ($key eq 'oauth_signature') {
      $hash->{oauth_signature} = $val;
    } elsif ($key eq 'realm') {
      $hash->{realm} = $val;
    } else {
      $hash->{_goauth}->{$key} = $val;
      $hash->{$key} = uri_unescape($val) if (grep {$_ eq $key} qw(oauth_token oauth_verifier oauth_consumer_key oauth_callback oauth_nonce oauth_timestamp));
    }
  }
  return 1053 unless ($hash->{oauth_signature} && $hash->{oauth_consumer_key});

  return;
}
  
sub oauth_header_make { # this is for client
  my $self = shift;
  my $current = shift;
  return "OAuth ".join(", ", map {$_.'="'.$current->{$_}.'"'} (keys %$current));
}

sub oauth_sign {
  my $self = shift;
  my ($method, $uri, $current, $combined) = @_;

  my $str = join('&',
    $method,
    uri_escape($uri),
    join("%26", map {$_."%3D".uri_escape($current->{$_})} (sort keys %$current))
  );

  my $key = $combined->[0].'&'.($combined->[1]||'');
  return uri_escape($self->digest64($key, $str));
}

sub oauth_verify {
  my $self = shift;
  my $combined = shift;
  my $hash = shift;

  unless ($hash->{_goauth}) {
    my $err = $self->oauth_header_get($hash);
    return $err if $err;
  }

  my $method = $self->get_method();
  my $uri    = $self->build_uri();

  return 1054 unless ($hash->{oauth_signature} eq $self->oauth_sign($method, $uri, $hash->{_goauth}, $combined));

  $hash->{$_} = $hash->{_goauth}->{$_} for (keys %{$hash->{_goauth}});
  delete $hash->{_goauth};
 
  return;
}

# the followings for client request
sub oauth_request {
  my $self = shift;
  my $method = shift;
  my $uri = shift;

  my $current;
  $current->{$_} = $self->{uc $_} for @_;

  $current->{oauth_signature} = $self->oauth_sign($method, $uri, $current, $self->{COMBINED});
  my %h = ("Authorization" => $self->oauth_header_make($current));
  $h{"x-li-format"} = $self->{"x-li-format"} if ($self->{"x-li-format"});

  $self->{UA} ||= LWP::UserAgent->new();
  return ($method eq 'GET') 
	? $self->ua_get($uri, %h)
	: $self->ua_post($uri, %h);
}

sub oauth_api {
  my $self = shift;
  my $back = shift;
  my $method = shift;
  my $uri = shift;
  
  my @fields = qw(oauth_consumer_key oauth_nonce oauth_signature_method oauth_token oauth_timestamp oauth_version);
  for ('oauth_token', 'combined', @fields) {
    return [1199, $_] unless $self->{uc $_};
  }

  $self->{"x-li-format"} = "json";
  my $body = $self->oauth_request($method, $uri, @fields);
  delete $self->{"x-li-format"};
  return 401 unless $body;

  my $parsed = decode_json($body);
  $back->{$_} = $parsed->{$_} for (keys %$parsed);

  return;
}

sub oauth_body {
  my $self = shift;
  my $back = shift;
  my $method = shift;
  my $uri = shift;

  my $body = $self->oauth_request($method, $self->{uc $uri}, @_);
  return 401 unless $body;
  my @a = split /&/, $body;
  for (@a) {
    my ($p, $v) = split '=', $_;
    $back->{$p} = $v;
  }

  return;
}

1;
