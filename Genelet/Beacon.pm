package Genelet::Beacon;

use strict;
use Data::Dumper;
use HTTP::Request::Common;
use HTTP::Response;
use Genelet::Dispatch;

use Genelet::Accessor;
use vars qw(@ISA);
@ISA = ('Genelet::Accessor');

__PACKAGE__->setup_accessors(
  config => {},
  lib    => '',
  ip     => '',
  comps  => [],
  tag    => '',
  role   => '',
  header => {'Content-Type' => "application/x-www-form-urlencoded"}
);

sub update_cookie {
  my $self = shift;
  my ($name, $value) = @_;
  my @a = split ';', $self->{HEADER}->{Cookie}, -1;
  my %b = ($name => $value);
  for my $cookie (@a) {
    $cookie =~ tr/^\s+//;
    my @two = split '=', $cookie, 2;
    next if ($two[0] eq $name);
    $b{$two[0]} = $two[1];
  }
  @a = ();
  for my $k (keys %b) {
    push @a, "$k=".$b{$k};
  }
  $self->{HEADER}->{Cookie} = join '; ', @a;
  return;
}

sub random_tag {
  my $self = shift;
  for my $tag (keys %{$self->{CONFIG}->{Chartags}}) {
    my $v = $self->{CONFIG}->{Chartags}->{$tag};
    if ($v->{"Content_type"} =~ /text\/html/i) {
      return $tag;
    }
  }

  return
}

sub get_mockup {
  my $self = shift;
  my ($obj, $query) = @_;
  my $role = $self->{ROLE};

  my $s_url = $self->{CONFIG}->{Server_url};
  my $script = $self->{CONFIG}->{Script};
  $query = "?$query" if $query;
  my $r = GET($s_url."$script/$role/".$self->{TAG}."/$obj".$query, %{$self->{HEADER}});
  my $output = Genelet::Dispatch::run_test($r, $self->{IP}, $self->{CONFIG}, $self->{LIB}, $self->{COMPS});
  return HTTP::Response->parse($output);
}

sub post_mockup {
  my $self = shift;
  my ($obj, $data) = @_;
  my $role = $self->{ROLE};

  my $s_url = $self->{CONFIG}->{Server_url};
  my $script = $self->{CONFIG}->{Script};

  my $r = POST($s_url."$script/$role/".$self->{TAG}."/$obj", %{$self->{HEADER}}, Content=>$data);
  my $output = Genelet::Dispatch::run_test($r, $self->{IP}, $self->{CONFIG}, $self->{LIB}, $self->{COMPS});
  return HTTP::Response->parse($output);
}

sub get_credential {
  my $self = shift;
  my ($login, $passwd) = @_;
  return "No password for $login." unless $passwd;
  my $role = $self->{ROLE};

  my $c = $self->{CONFIG};
  my $go_uri = $c->{Go_uri_name} || "go_uri";
  my $go_probe = $c->{Go_probe_name} || "go_probe";
  my $obj_role = $c->{Roles}->{$role};
  my $surface = $obj_role->{Surface};
  my ($field_login, $field_passwd);
  for my $provider (keys %{$obj_role->{Issuers}}) {
    my $v = $obj_role->{Issuers}->{$provider};
    $field_login = $v->{Credential}->[0];
    $field_passwd = $v->{Credential}->[1];
    last if $v->{Default};
  }
  my $tag = $self->random_tag();
  my $orig = $self->{TAG};
  $self->{TAG} = $tag;
  my $resp = $self->post_mockup($c->{Login_name} || "login", [
    $go_uri=>$c->{Script}."/$role/$tag/".lc($self->{COMPS}->[0]),
    $field_login=>$login,
    $field_passwd=>$passwd]);
  $self->{TAG} = $orig;
  if ($resp->code() == 303) {
    my @cookies = $resp->header("Set-Cookie");
    for my $cookie (@cookies) {
      if ($cookie =~ /^$surface=(\S+)?;/) {
        $self->update_cookie($surface,$1);
        return;
      }
    }
  }

  return "Login failed";
}

1;
