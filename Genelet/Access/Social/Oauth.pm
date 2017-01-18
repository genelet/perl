package Genelet::Access::Social::Oauth;

# oauth_callback can be overridden
use strict;
use URI::Escape;
use Genelet::Access::Social;
use Genelet::Oauth;
use Genelet::Scoder;

use vars qw(@ISA $VERSION);
$VERSION = '1.01';

@ISA = ('Genelet::Access::Social', 'Genelet::Oauth');

__PACKAGE__->setup_accessors(
  combined              => [],
  oauth_callback        => '',
  oauth_consumer_key    => '',
  oauth_consumer_secret => '',
  oauth_signature_method=> 'HMAC-SHA1',
  oauth_version         => '1.0',

  oauth_request_token   => "",
  oauth_authorize_uri   => "",
  oauth_access_token    => "",
  oauth_endpoint  => "",
);

sub handler {
  my $self = shift;

  $self->{CREDENTIAL} = ['oauth_token', 'oauth_verifier'];
  return $self->handler_login();
}

sub authenticate {
  my $self = shift;
  my ($login, $password, $uri) = @_;

  my $err; 
  $self->{OAUTH_TIMESTAMP} = time();
  $self->{OAUTH_NONCE}     = sprintf("%x%8x", $$, $self->{OAUTH_TIMESTAMP});
  my $back = {};

  $self->warn("{Oauth}[In]{start}1");
  unless ($login) { # get token
    $self->warn("{Oauth}[RequestToken]{start}1");
    $self->warn("{Oauth}[RequestToken]{URL}".$self->{OAUTH_REQUEST_TOKEN});
    $self->{COMBINED} = [$self->{OAUTH_CONSUMER_SECRET}];
    $self->{OAUTH_CALLBACK} = uri_escape($self->get_callback($uri));
    $err = $self->oauth_body($back, 'GET', qw(oauth_request_token oauth_callback oauth_consumer_key oauth_nonce oauth_signature_method oauth_timestamp oauth_version));
    $err ||= 403 unless ($back->{oauth_token} && $back->{oauth_token_secret}); #$back{oauth_token oauth_token_secret oauth_callback};
    $self->warn("{Oauth}[RequestToken]{end}1:$err");
    return $err if $err;
    my $dest = $self->{OAUTH_AUTHORIZE_URI};
    $dest .= ($self->{OAUTH_AUTHORIZE_URI} =~ /\?/) ? '&' : '?';
    $dest .= "oauth_token=".$back->{oauth_token};
    $dest .= "&oauth_callback=".$self->{OAUTH_CALLBACK} unless $back->{oauth_callback_confirmed};
    $self->{R}->{headers_out}->{"Location"} = $dest;
    $self->set_cookie($self->{$self->{PROVIDER_NAME}}, encode_scoder($back->{oauth_token_secret}, $self->{CODING}));
    $self->warn("{Oauth}[In]{end}1");
    return 303; # redirect to authorizer
  }

  $self->warn("{Oauth}[Authorize]{start}1");
  # after authorize, user is redirected here, with vars in login and passwd 
  $self->{OAUTH_TOKEN}    = $login; 
  $self->{OAUTH_VERIFIER} = $password; 

  $self->{OAUTH_TOKEN_SECRET} = $self->get_cookie($self->{$self->{PROVIDER_NAME}});
  unless ($self->{OAUTH_TOKEN_SECRET}) {
    $self->warn("{Oauth}[Authorize]{TokenSecret}Missing");
    return 404;
  }
  $self->{OAUTH_TOKEN_SECRET} = decode_scoder($self->{OAUTH_TOKEN_SECRET}, $self->{CODING});
  $self->{COMBINED} = [$self->{OAUTH_CONSUMER_SECRET}, $self->{OAUTH_TOKEN_SECRET}];

  $err = $self->oauth_body($back, 'GET', qw(oauth_access_token oauth_consumer_key oauth_nonce oauth_signature_method oauth_token oauth_timestamp oauth_verifier oauth_version));
  $self->warn("{Oauth}[Authorize]{end}1:$err");
  return $err if $err;

  $self->warn("{Oauth}[Access]{start}1");
  # final token and secret here
  $self->{OAUTH_TOKEN}        = $back->{oauth_token};
  $self->{OAUTH_TOKEN_SECRET} = $back->{oauth_token_secret};
  $self->{COMBINED} = [$self->{OAUTH_CONSUMER_SECRET}, $self->{OAUTH_TOKEN_SECRET}];
  $self->warn("{Oauth}[EndPoint]{Url}".$self->{OAUTH_ENDPOINT});
  if ($self->{OAUTH_ENDPOINT}) {
    $err = $self->oauth_api($back, 'GET', $self->{OAUTH_ENDPOINT}) and return $err;
  }
  $self->warn("{Oauth}[EndPoint]{end}1:$err");

  return $self->fill_provider($back, $uri);
}
 
1;
