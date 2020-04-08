package Genelet::Access::Social::Github;

use strict;
use JSON;
use Genelet::Access::Social::Oauth2;

use vars qw(@ISA $VERSION);
$VERSION = '1.01';

@ISA = ('Genelet::Access::Social::Oauth2');

__PACKAGE__->setup_accessors(
  scope            => "repo_deployment,repo:invite,user:email",
  response_type    => "code",
  grant_type       => "authorization_code",
  authorize_url    => "https://github.com/login/oauth/authorize",
  access_token_url => "https://github.com/login/oauth/access_token",
  endpoint         => "https://api.github.com/user",
);

# in_pars defines which keys we want
sub get_token {
  my $self = shift;
  my $back = $self->SUPER::get_token(@_);
  
  my $saved = $self->get_cookie($self->{PROVIDER_NAME});
  if ($saved) {
    my $hash = decode_json($saved);
    foreach my $k (keys %$hash) {
      $back->{$k} = $hash->{$k};
    }
  }

  return $back;
}

sub oauth2_api {
  my $self = shift;
  my $back = shift;
  $self->SUPER::oauth2_api($back, @_);
  my @a = split /\s+/, $back->{name}, 2;
  $back->{firstname} = $a[0];
  $back->{lastname} = $a[1];

  return;
}


1;
