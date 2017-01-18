package Genelet::Postmark;
#interface 

use strict;
#use JSON;

sub send_mail {
  my $self = shift;
  my ($pars, $output, $smtp) = @_;

  return 1060 unless ($pars->{Server} && $pars->{From} && $pars->{To} && $pars->{Subject});

  my $token = $pars->{token};
  my $uri  = $pars->{Server};
  my $type  = $pars->{type} || 'text';
  delete $pars->{token};
  delete $pars->{Server};
  delete $pars->{type} if $pars->{type};

  my $ua = $self->{UA} || LWP::UserAgent->new();
  my %h = (
	"Accept" => "application/json",
	"Content-Type" => "application/json",
	"X-Postmark-Server-Token" => $token
  );

  if ($type eq 'text') {
    $pars->{textBody} = $output
  } else {
    $pars->{HtmlBody} = $output;
  }

  my $response = $ua->post($uri, %h, Content=>JSON::encode_json($pars));
  unless ($response->is_success()) {
    $self->warn($response->content());
    $self->warn(JSON::encode_json($pars));
    return 1111;
  }
  my $body = JSON::decode_json($response->content());
  return unless $body->{ErrorCode};
  return 1113 if ($body->{ErrorCode} == 300);
  return $body->{ErrorCode}- 400 + 1100;
}

1;
