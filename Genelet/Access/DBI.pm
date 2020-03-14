package Genelet::Access::DBI;

use strict;
use Genelet::Access::Ticket;
use Genelet::Access::Procedure;

use vars qw(@ISA $VERSION);
$VERSION = '1.01';

@ISA = ('Genelet::Access::Ticket', 'Genelet::Access::Procedure');

__PACKAGE__->setup_accessors(
  sql  => '',
  sql_as  => '',
  screen => 0,
);

sub authenticate {
  my $self = shift;
  #my ($login, $password, $uri) = @_;

  #my $in_vals = [$login, $password];
  my $in_vals = [@_];
  push(@$in_vals, $self->get_ip_int())  if ($self->{SCREEN} & 1);
  push(@$in_vals, $self->get_ua())      if ($self->{SCREEN} & 2);
  push(@$in_vals, $self->get_referer()) if ($self->{SCREEN} & 4);
  #push(@$in_vals, $uri)                 if ($self->{SCREEN} & 8);

  #return $self->run_sql($self->{SQL}, $in_vals) || $self->_authentication($login);
  return $self->run_sql($self->{SQL}, $in_vals) || $self->_authentication($_[0]);
}

sub authenticate_as {
  my $self = shift;
  my ($login) = @_;

  #my $in_vals = [$login];
  my $in_vals = [@_];
  return $self->run_sql($self->{SQL_AS}, $in_vals) || $self->_authentication($login);
}

sub _authentication {
  my $self = shift;
  my $login = shift;

  for my $k (@{$self->{ATTRIBUTES}}) {
    if ($k eq $self->{CREDENTIAL}->[0]) {
      $self->{OUT_HASH}->{$k} = $login;
      last;
    }
  }
  my $out_pars = $self->{OUT_PARS} || $self->{ATTRIBUTES};
  my $out_hash = $self->{OUT_HASH};

  return if defined($out_hash->{$out_pars->[0]});
  return $out_hash->{$out_pars->[1]} ? $out_hash->{$out_pars->[1]} : 1032;
}

1;
