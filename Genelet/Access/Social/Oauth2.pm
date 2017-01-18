package Genelet::Access::Social::Oauth2;

use strict;
use URI::Escape;
use Genelet::Oauth2;
use Genelet::Access::Social;

use vars qw(@ISA $VERSION);
$VERSION = '1.01';

@ISA = ('Genelet::Oauth2', 'Genelet::Access::Social');

__PACKAGE__->setup_accessors(
  client_id     => undef,
  client_secret => undef,

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

sub authenticate {
  my $self = shift;
  my ($login, $password, $uri) = @_;

  $self->warn("{Oauth2}[In]{start}1");
  unless ($login) {
    $self->warn("{Oauth2}[Authorize]{error}1:".$password);
    return 400 if $password; # authorization failed
    $self->warn("{Oauth2}[Authorize]{URL}".$self->{AUTHORIZE_URL});
    my $dest = $self->{AUTHORIZE_URL}."?client_id=".$self->{CLIENT_ID}."&redirect_uri=".uri_escape($self->get_callback($uri));
    for (qw(scope display state response_type)) {
      $dest .= "&$_=".$self->{uc $_} if ($self->{uc $_});
    }
    $self->{R}->{headers_out}->{"Location"} = $dest;
    
    $self->warn("{Oauth2}[In]{end}1");
    return 303;
  }
 
  $self->warn("{Oauth2}[AccessToken]{start}1");
  my $form = {
    code         =>$login,
    client_id    =>$self->{CLIENT_ID},
    client_secret=>$self->{CLIENT_SECRET},
    redirect_uri =>$self->get_callback($uri),
  };
  $form->{grant_type} = $self->{GRANT_TYPE} if $self->{GRANT_TYPE};

  my $body = $self->oauth2_request($self->{TOKEN_METHOD_GET} ? "GET" : "POST", $self->{ACCESS_TOKEN_URL}, $form);
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

  return $self->fill_provider($back, $uri);
}

1;
