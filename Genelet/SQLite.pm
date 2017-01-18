package Genelet::SQLite;
#interface 

use strict;

sub last_insertid {
  return shift->{DBH}->sqlite_last_insert_rowid();
}

sub guess_fields {
  my $self = shift;

  my $lists = [];
  my $err = $self->select_sql_label($lists, "PRAGMA table_info(".$self->{CURRENT_TABLE}.")", [qw(Rowid Field Type Isnull Default Incre)]);
  return $err if $err;

  $self->{GUESSED} = [map {$_->{Field}} @$lists];

  return;
}

1;
