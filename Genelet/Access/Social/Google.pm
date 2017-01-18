package Genelet::Access::Social::Google;

use strict;
use Genelet::Access::Social::Oauth2;

use vars qw(@ISA $VERSION);
$VERSION = '1.01';

@ISA = ('Genelet::Access::Social::Oauth2');

__PACKAGE__->setup_accessors(
  scope            => "https://www.googleapis.com/auth/userinfo.profile",
  response_type    => "code",
  grant_type       => "authorization_code",
  authorize_url    => "https://accounts.google.com/o/oauth2/auth",
  access_token_url => "https://accounts.google.com/o/oauth2/token",
  endpoint         => "https://www.googleapis.com/oauth2/v1/userinfo",
);

1;
