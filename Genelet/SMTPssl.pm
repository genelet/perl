package Genelet::SMTPssl;
#interface 

use strict;
use Net::SMTP::SSL;
use Genelet::SMTP;

use vars qw(@ISA);
@ISA = ('Genelet::SMTP');

sub send_mail {
  my $self = shift;
  my ($pars, $output) = @_;

  my ($server, $port) = split /:/, $pars->{Server};
  my $smtp = Net::SMTP::SSL->new($server, SSL_verify_mode=>0, Port=>$port, Hello=>$pars->{Hello}, Debug=>$pars->{Debug}) or return [1205, $!];
  return $self->SUPER::send_mail($pars, $output, $smtp);
}

1;
