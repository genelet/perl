package Genelet::Access::Anonymous;

use strict;
use URI;
use vars qw(@ISA);

use Genelet::Access::Ticket;
@ISA = ('Genelet::Access::Ticket');

my $segment = 0;
sub handler {
  my $self = shift;

  my $ip = $self->raw_p();
  $segment++;
  $segment -= 65536 if ($segment >= 65536);
  my  $when = $self->get_when();
  my $login = sprintf('%08x%08x%04x%04x', $when, unpack("N", pack("C4", split(/\./, $ip))), $$, $segment);

  my $uri = $self->{R}->param($self->{GO_URI_NAME}) || $self->get_cookie($self->{GO_PROBE_NAME});
  $self->{OUT_PARS} = ['login'];
  $self->{OUT_HASH} = {'login'=>$login};
  return $self->handler_fields($uri);
}

1;

