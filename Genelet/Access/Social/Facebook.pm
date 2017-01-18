package Genelet::Access::Social::Facebook;

use strict;
use Genelet::Access::Social::Oauth2;

use vars qw(@ISA $VERSION);
$VERSION = '1.01';

@ISA = ('Genelet::Access::Social::Oauth2');

__PACKAGE__->setup_accessors(
  authorize_url    => "https://www.facebook.com/dialog/oauth",
  access_token_url => "https://graph.facebook.com/oauth/access_token",
  endpoint         => "https://graph.facebook.com/me",
);

sub get_token {
  my $self = shift;
  my $access_token = shift;

  my ($token, $duration);
  foreach my $part (split(/&/, $access_token)) {
    my ($a, $b) = split '=', $part;
    if ($a eq 'access_token') {
      $token = $b;
    } elsif ($a eq 'expires') {
      $duration = $b;
    }
  }

  return unless $token;
  #return 401 unless $token;
  return {access_token=>$token, expires=>$duration};
}

1;
