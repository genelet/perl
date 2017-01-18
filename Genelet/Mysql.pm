package Genelet::Mysql;
#interface 

use strict;

sub last_insertid {
  return shift->{DBH}->{mysql_insertid};
}

sub guess_fields {
  my $self = shift;

  my $lists = [];
  my $err = $self->select_sql($lists, "DESC ".$self->{CURRENT_TABLE});
  return $err if $err;

  $self->{GUESSED} = [map {$_->{Field}} @$lists];

  return;
}

1;
