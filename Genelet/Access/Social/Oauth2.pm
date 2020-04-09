package Genelet::Access::Social::Oauth2;

use strict;
use Data::Dumper;
use URI::Escape;
use Genelet::Oauth2;
use Genelet::Access::Social;

use vars qw(@ISA $VERSION);
$VERSION = '1.01';

@ISA = ('Genelet::Oauth2', 'Genelet::Access::Social');

__PACKAGE__->setup_accessors(
  client_id     => undef,
  client_secret => undef,
  callback_url  => undef,

  scope         => undef,
  display       => undef,
  state         => undef,
  response_type => undef,
  grant_type    => undef,

  authorize_url    => undef,
  access_token_url => undef,
  access_token     => undef,
  token_method_get => undef,
  endpoint         => undef,
);

sub handler {
  my $self = shift;

  $self->{CREDENTIAL} = ['code', 'error'];
  return $self->handler_login();
}

sub build_authorize {
	my $self = shift;
	my $url = shift;
	my $state = shift;

	my $obj = shift;
	my $saved = shift;
	my $final = shift;

	my $dest = $self->{AUTHORIZE_URL}."?client_id=".$self->{CLIENT_ID}."&redirect_uri=".uri_escape($url);
    for (qw(scope display response_type)) {
      $dest .= "&$_=".$self->{uc $_} if ($self->{uc $_});
    }
   	$dest .= "&state=".$state if $state;
	if ($obj) {
   		$obj->set_cookie($self->{PROVIDER_NAME}."_1", $url);
   		$obj->set_cookie($self->{PROVIDER_NAME}, $saved) if $saved;
		$obj->set_cookie($self->{GO_PROBE_NAME}, $final) if $final;
	}

	return $dest;
}

sub authenticate {
  my $self = shift;
  my ($login, $password, $uri) = @_;

  $self->warn("{Oauth2}[In]{start}1");
  unless ($login) {
    $self->warn("{Oauth2}[Authorize]{error}1:".$password);
    return 400 if $password; # authorization failed
    $self->warn("{Oauth2}[Authorize]{URL}".$self->{AUTHORIZE_URL});
	$self->{R}->{headers_out}->{"Location"} = $self->build_authorize($self->{CALLBACK_URL}||$self->get_callback($uri), $self->{R}->param("state"));
	$self->set_cookie($self->{GO_PROBE_NAME}, $uri);	
    $self->warn("{Oauth2}[In]{end}1");
    return 303;
  }
 
  my $state = $self->{R}->param("state");
  my $next_url = $self->get_cookie($self->{PROVIDER_NAME}."_1") || $self->{CALLBACK_URL} || $self->get_callback($uri);

  $self->warn("{Oauth2}[AccessToken]{start}1");
  my $form = {
    code         =>$login,
    client_id    =>$self->{CLIENT_ID},
    client_secret=>$self->{CLIENT_SECRET},
    redirect_uri =>$next_url
  };
  $form->{state} = $state if $state;
  $form->{grant_type} = $self->{GRANT_TYPE} if $self->{GRANT_TYPE};
  $self->warn("{Oauth2}[RequestToken]{start}1");
  my $body = $self->oauth2_request($self->{TOKEN_METHOD_GET} ? "GET" : "POST", $self->{ACCESS_TOKEN_URL}, $form);
  $self->warn("{Oauth2}[RequestToken]{end}1");
  unless ($body) {
    $self->warn("{Oauth2}[AccessToken]{end}1:401A");
    return 401;
  }
  my $back = $self->get_token($body);
  unless ($back && $back->{access_token}) {
    $self->warn("{Oauth2}[AccessToken]{end}1:401B");
    return 401;
  }
  $self->warn("{Oauth2}[AccessToken]{end}1");

  $self->{ACCESS_TOKEN} = $back->{access_token};
  if ($self->{ENDPOINT}) {
    $self->warn("{Oauth2}[EndPoint]{Url}".$self->{OAUTH_ENDPOINT});
    my $err = $self->oauth2_api($back, "GET", $self->{ENDPOINT});
    $self->warn("{Oauth2}[EndPoint]{end}1:$err");
    return $err if $err;
  }
  #$self->warn(Dumper($back));

  # In_pars shows keys in %$back
  return $self->fill_provider($back, $uri || $self->get_cookie($self->{GO_PROBE_NAME}));
}

1;
