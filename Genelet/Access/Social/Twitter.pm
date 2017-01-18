package Genelet::Access::Social::Twitter;

# 2) oauth_callback can be overridden
use strict;
use Genelet::Access::Social::Oauth;

use vars qw(@ISA $VERSION);
$VERSION = '1.01';

@ISA = ('Genelet::Access::Social::Oauth');

__PACKAGE__->setup_accessors(
  oauth_request_token   => "https://api.twitter.com/oauth/request_token",
  oauth_authorize_uri   => "https://api.twitter.com/oauth/authorize",
  oauth_access_token    => "https://api.twitter.com/oauth/access_token",
# oauth_endpoint        => "http://api.twitter.com/1/account/settings.json",
);

1;
