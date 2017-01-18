package Genelet::Access::Social;

use strict;

use URI::Escape;
use Genelet::Access::Ticket;
use Genelet::Access::Procedure;
use vars qw(@ISA $VERSION);

$VERSION = 1.01;
@ISA = ('Genelet::Access::Ticket', 'Genelet::Access::Procedure');

__PACKAGE__->setup_accessors(
  sql  => '',
  in_pars => [],
  auth_par=> undef,
);

sub get_callback {
  my $self = shift;
  my $uri = shift;

  my $full = $self->get_scriptfull()."/".$self->provider()."/".$self->{ROLE_VALUE};
  $full .= "?".$self->{GO_URI_NAME}."=".uri_escape($uri) if $uri;
  return $full;
}

sub fill_provider {
  my $self = shift;
  my ($back, $uri) = @_;

  $self->warn("{Oauth12}[Provider]{start}1");
  $back->{remote_addr} ||= $self->get_ip();
  $back->{remote_ipint} ||= $self->get_ip_int();

  my $last;
  if ($self->{AUTH_PAR}) {
    my $code = $self->verify_cookie();
    $self->warn("{Oauth12}[Provider]{code}1:$code");
    $last = $self->{AUTH}->{$self->{AUTH_PAR}} if (!$code && $self->{AUTH}->{$self->{AUTH_PAR}});
  }

  if ($self->{SQL}) {
    $self->warn("{Oauth12}[Provider]{SQL}".$self->{SQL});
    my $in_vals;
    for my $par (@{$self->{IN_PARS}}) {
      my $val = $self->{uc $par} || $back->{$par};
      unless (defined($val)) {
        $self->warn("{Oauth12}[Provider]{Missing}$par");
        return 1144;
      }
      push @$in_vals, $val;
    }
    push(@$in_vals, $last) if ($self->{AUTH_PAR});
    my $err = $self->run_sql($self->{SQL}, $in_vals);
    if ($err) {
      $self->warn("{Oauth12}[Provider]{end}1:$err");
      return $err;
    }
  }

  if ($last) {
    $self->{R}->{headers_out}->{"Location"} = $uri;
    $self->warn("{Oauth12}[Provider]{end}1:303");
    return 303;
  }
  my $out_pars = $self->{OUT_PARS} || $self->{ATTRIBUTES};
  my $out_hash = $self->{OUT_HASH};
  for (@$out_pars) {
    $out_hash->{$_} = $back->{$_} unless defined($out_hash->{$_});
  }
  return 1032 unless defined($out_hash->{$out_pars->[0]});

  $self->warn("{Oauth12}[Provider]{end}1");
  return;
}

1;
