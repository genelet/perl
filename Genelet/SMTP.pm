package Genelet::SMTP;
#interface 

use strict;
use Net::SMTP;

sub send_mail {
  my $self = shift;
  my ($pars, $output, $smtp) = @_;

  return 1060 unless ($pars->{Server} && $pars->{From} && $pars->{To} && $pars->{Subject});

  my ($server, $port) = split /:/, $pars->{Server};
  $smtp ||= Net::SMTP->new($server, Port=>($port||25), Hello=>$pars->{Hello}, Debug=>$pars->{Debug}) or return [1063, $!];
  $smtp->auth(split(/,/, $pars->{Auth})) if ($pars->{Auth});
  $smtp->mail($pars->{Sender});
  $smtp->to($pars->{To});
  $smtp->data();
  $smtp->datasend("Content-Type: ".$pars->{'Content_Type'}."\r\n") if $pars->{Content_Type};
  my $t = ($pars->{To_Name}) ? '"'.$pars->{To_Name}.'" <'.$pars->{To}.'>' : $pars->{To};
  $smtp->datasend("To: $t\r\n");
  $smtp->datasend("From: $pars->{From}\r\n");
  $smtp->datasend("Reply-To: $pars->{Reply_To}\r\n") if $pars->{Reply_To};
  $smtp->datasend("Subject: ".$pars->{Subject}."\r\n\r\n");
  $smtp->datasend($output."\r\n");
  $smtp->dataend();
  $smtp->quit or return [1062, $!];
  return;
}

1;
