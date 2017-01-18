package Genelet::GCM;

use strict;
use JSON;
use LWP::UserAgent;

sub send_gcm {
  my $self = shift;
  my ($api_key, $hash, $registration_ids, $delay_while_idle, $time_to_live, $collapse_key) = @_;

  return "No API key" unless $api_key;
  return "No data or registation ids" unless ($hash && $registration_ids); 
  
  my $pars = { data=>$hash, registration_ids=>$registration_ids };
  $pars->{delay_while_idle} = $delay_while_idle if defined($delay_while_idle);
  $pars->{time_to_live} = $time_to_live if defined($time_to_live);
  $pars->{collapse_key} = $collapse_key if defined($collapse_key);

  my $ua = $self->{UA} || LWP::UserAgent->new();
  my %h = (
	"Authorization" => "key=".$api_key,
	"Accept" => "application/json",
	"Content-Type" => "application/json",
  );

  my $response = $ua->post("https://android.googleapis.com/gcm/send", %h, Content=>JSON::encode_json($pars));
  unless ($response->is_success()) {
    if ($self->{LOGGER}) {
      $self->{LOGGER}->warn($response->content());
      $self->{LOGGER}->warn(JSON::encode_json($pars));
    }
    return 1111;
  }

# need to handle msg
  return;
}

1;
