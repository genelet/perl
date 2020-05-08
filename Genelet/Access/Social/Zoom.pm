package Genelet::Access::Social::Zoom;

use strict;
use MIME::Base64;
use Genelet::Access::Social::Oauth2;

use vars qw(@ISA $VERSION);
$VERSION = '1.01';

@ISA = ('Genelet::Access::Social::Oauth2');

__PACKAGE__->setup_accessors(
  scope            => "user:read:admin",
  response_type    => "code",
  grant_type       => "authorization_code",
  authorize_url    => "https://zoom.us/oauth/authorize",
  access_token_url => "https://zoom.us/oauth/token",
  endpoint         => "https://api.zoom.us/v2/users/me",
);

sub get_me {
  my $self = shift;
  return (undef, {'Authorization'=> "Bearer ".$self->{ACCESS_TOKEN}});
}

sub get_token_body {
  my $self = shift;
  my ($login, $redirect_uri, $state) = @_;
  my $form = {
    code         =>$login,
    client_id    =>$self->{CLIENT_ID},
    client_secret=>$self->{CLIENT_SECRET},
    redirect_uri =>$redirect_uri
  };
  $form->{state} = $state if $state;
  $form->{grant_type} = $self->{GRANT_TYPE} if $self->{GRANT_TYPE};
  my $headers = {Authorization=>"Basic " . MIME::Base64::encode($self->{CLIENT_ID}.":".$self->{CLIENT_SECRET}, "")};
  $self->warn("{Oauth2}[RequestToken]{start}1");
  return $self->oauth2_request($self->{TOKEN_METHOD_GET} ? "GET" : "POST", $self->{ACCESS_TOKEN_URL}, $form, $headers);
}

1;
