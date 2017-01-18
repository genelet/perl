package Genelet::MIMELite;

use strict;
use MIME::Lite;

sub send_mail {
  my $self = shift;
  my ($pars, $output) = @_;

  my %build = (
	Sender => $pars->{Sender},
	From => $pars->{From},
	To => ($pars->{To_Name}) ? '"'.$pars->{To_Name}.'" <'.$pars->{To}.'>' : $pars->{To},
	Subject => $pars->{Subject},
	Data => $output
  );
  $build{"Cc"} = $pars->{Cc} if $pars->{Cc};
  $build{"Reply-To"} = $pars->{Reply_To} if $pars->{Reply_To};
  #$build{"Type"} = $pars->{'Content_Type'} if $pars->{Content_Type};
  my $msg = MIME::Lite->new(%build);
  $msg->send;

  return;
}

1;
