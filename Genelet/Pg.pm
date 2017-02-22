package Genelet::Pg;
#interface 

use strict;

sub last_insertid {
  my $self = shift;

  my $hash;
  my $err = $self->select_sql($hash,
	"SELECT CURRVAL(pg_get_serial_sequence('".$self->{CURRENT_TABLE}."', '".$self->{CURRENT_KEY}."')) AS auto_id");
  die $err if $err;
  
  return $hash->{auto_id};
}

1;
