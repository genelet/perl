# json_uri if enabled, it will not redirect, as in most json cases
# json_challenge, used in cgicontoller, to return a challenge notice in json
# json_logged, used in ticket, to note the login is successful
# json_failed, used in ticket, to note the login is failed

package Genelet::Access;

use strict;
use warnings;
use URI::Escape;
use Genelet::Base;
use Genelet::Scoder;

use vars qw(@ISA);
@ISA = ('Genelet::Base');

__PACKAGE__->setup_accessors(
  coding    => '',
  surface   => '',
  length    => 0,
  duration  => 0,
  grouplevel=> 0,
  userlist  => undef,
  grouplist => undef,

  domain    => '',
  path      => '/',
  max_age   => undef,

  go_probe_name => "go_probe",
  go_err_name   => "go_err",
  static    => undef,

  auth      => undef,

  role_value => "",
  chartag_value => "",
);

sub signature {
  my $self = shift;
  my ($fields) = @_;

  my $login = uri_escape(shift @$fields);
  my $group = (@$fields) ? join('|', map {defined($_) ? uri_escape($_) : ''} @$fields) : $self->{GROUPLEVEL}+1;

  return $self->_signature($login, $group);
}

sub reset_signature {
  my $self = shift;
  my ($value, $i) = @_;

  my $auth = $self->{AUTH};
  return unless $auth;
  my @groups = split /\|/, $auth->{"X-Forwarded-Group"}, -1;
  $self->debug($auth->{"X-Forwarded-Group"});
  if (ref($value) eq 'ARRAY' and ref($i) eq 'ARRAY') {
    my $n=scalar(@$i);
    for (0..($n-1)) {
      $groups[$i->[$_]] = $value->[$_];
    } 
  } elsif (!ref($value) and !ref($i)) {
    $groups[$i] = $value;
  }
  $self->debug(join('|', @groups));

  return $self->_signature($auth->{"X-Forwarded-User"}, join('|', @groups));
}

sub _signature {
  my $self = shift;
  my ($login, $group) = @_;

  my $request_time = $self->get_when();
  my $when = $request_time+$self->{DURATION};
  my $raw_ip = $self->get_ip();
  my $ip = ($self->{LENGTH}) ? substr(join('', map {sprintf('%02X', $_)} split(/\./, $raw_ip)), 0, $self->{LENGTH}) : 1;

  my $hash = $self->digest($self->{SECRET}, $ip.$login.$group.$when);
  my $value = join('/', $ip, $login, $group, $when, $hash);
  $self->debug(join("\n", $value, $raw_ip, $request_time, $ip, $login,
	$group, $when, $hash, $self->{LENGTH}, $self->{DURATION}));

  $value = encode_scoder($value, $self->{CODING}) if $self->{CODING};

  return $value;
}

sub verify_cookie {
  my $self = shift;
  my $raw = shift || $self->get_cookie($self->{SURFACE});
  return 1020 unless $raw;

  my $value = $raw;
  $value = decode_scoder($raw, $self->{CODING}) if $self->{CODING};

  my $raw_ip = $self->get_ip();
  my $request_time = $self->get_when();

  my ($ip, $login, $group, $when, $hash) = split '/', $value, -1;

  $self->debug(join("\n", $value, $raw_ip, $request_time, $ip, $login,
	$group, $when, $hash, $self->{LENGTH}, $self->{DURATION}));

  return 1020 unless $hash;
   
  return 1023 if ($self->{LENGTH} && (substr(join('', map {sprintf('%02X', $_)} split(/\./, $raw_ip)), 0, $self->{LENGTH}) ne $ip));

  return 1022 if ($self->{DURATION} && $request_time>$when);

  my $found = 0;
  if ($self->{GROUPLEVEL} && $self->{GROUPLEVEL}>0) {
    $found = 1 if ($group=~/^\d+$/ && $group >= $self->{GROUPLEVEL});
  } elsif ($self->{GROUPLIST}) {
    $found = 1 if (grep {/$group/} @{$self->{GROUPLIST}});
  } elsif ($self->{USERLIST}) {
    $found = 1 if (grep {/$login/} @{$self->{USERLIST}});
  } else {
    $found = 1;
  }
  return 1021 unless $found;

  $self->debug($self->digest($self->{SECRET}, $ip.$login.$group.$when));
  if ($self->digest($self->{SECRET}, $ip.$login.$group.$when) eq $hash) {
    $self->{AUTH} = {
		"X-Forwarded-Time" => $when,
		"X-Forwarded-User" => $login,
		"X-Forwarded-Group"=> $group,
		"X-Forwarded-Duration" => $self->{DURATION},
		"X-Forwarded-Request_Time" => $request_time,
		"X-Forwarded-Raw" => $raw,
		"X-Forwarded-Hash" => $hash
    };
    return;
  }

  return 1024;
}
 
1;
