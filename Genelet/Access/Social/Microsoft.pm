package Genelet::Access::Social::Microsoft;

use strict;
use Genelet::Access::Social::Oauth2;

use vars qw(@ISA $VERSION);
$VERSION = '1.01';

@ISA = ('Genelet::Access::Social::Oauth2');

__PACKAGE__->setup_accessors(
  response_type    => 'code',
  scope            => 'wl.basic%20wl.offline_access%20wl.emails%20wl.skydrive',

  authorize_url    => "https://oauth.live.com/authorize",
  access_token_url => "https://oauth.live.com/token",
  grant_type       => 'authorization_code',
  token_method_get => 1,
  endpoint         => "https://apis.live.net/v5.0/me",
);

1;
