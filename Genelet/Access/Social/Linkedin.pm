package Genelet::Access::Social::Linkedin;

use strict;
use Genelet::Access::Social::Oauth;

use vars qw(@ISA $VERSION);
$VERSION = '1.01';

@ISA = ('Genelet::Access::Social::Oauth');

__PACKAGE__->setup_accessors(
  oauth_request_token   => "https://api.linkedin.com/uas/oauth/requestToken",
  oauth_authorize_uri   => "https://api.linkedin.com/uas/oauth/authenticate",
  oauth_access_token    => "https://api.linkedin.com/uas/oauth/accessToken",
  oauth_endpoint        => "http://api.linkedin.com/v1/people/~:(id,first-name,last-name,publicProfileUrl,pictureUrl)",
);

1;
