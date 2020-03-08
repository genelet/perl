package Genelet::DBI;

use strict;
use Genelet::Accessor;
use vars qw(@ISA);
@ISA = ('Genelet::Accessor');

__PACKAGE__->setup_accessors(
	dbh => {},
	logger => {},
	affected => 0
);

sub execute_sth {
  my $self = shift;
  my $sth = shift;

  eval {
    my $rv = (@_) ? $sth->execute(@_) : $sth->execute();
    unless ($rv) {
      $self->{LOGGER}->warn($self->{DBH}->errstr()) if $self->{LOGGER};
      die 1073;
    }
    $self->{AFFECTED} = $rv;
  };
  if ($@) {
    return ($@ =~ /1073/) ? 1073 : 1074;
  }

  return;
};

my $sql_err = sub {
  my ($sql, $err) = @_;
  return $err unless ($err==1073);

  return ($sql =~ /^insert/i) ? 1171 :
    ($sql =~ /^delete/i) ? 1172 :
    ($sql =~ /^update/i) ? 1173 :
    ($sql =~ /^select/i) ? 1174 :
    ($sql =~ /^call/i) ? 1175 : $err;
};

sub do_sql {
  my $self = shift;
  my $sql = shift;

  if ($self->{LOGGER}) {
    $self->{LOGGER}->warn($sql);
    $self->{LOGGER}->warn(\@_) if @_;
  }
  my $sth = $self->{DBH}->prepare($sql);
  my $err = $self->execute_sth($sth, @_);
  return $sql_err->($sql, $err) if $err;
  return;
}

sub do_sqls {
  my $self = shift;
  my $sql = shift;

  if ($self->{LOGGER}) {
    $self->{LOGGER}->warn($sql);
    $self->{LOGGER}->warn(\@_) if @_;
  }

  my $sth = $self->{DBH}->prepare($sql);
  my $err;
  foreach my $record (@_) {
    $err = $self->execute_sth($sth, @$record) and return $sql_err->($sql, $err);
  }

  return;
}

sub select_sql {
  my $self = shift;
  my $lists = shift;
  my $sql = shift;

  return $self->select_sql_label($lists, $sql, undef, @_);
}

sub get_args {
  my $self = shift;
  my $args = shift;
  my $sql = shift;
  my $lists = [];

  my $err = $self->select_sql($lists, $sql, @_);
  return $err if $err;
  return unless ($lists && $lists->[0]);
  while (my ($k, $v) = each %{$lists->[0]}) {
    $args->{$k} = $v;
  }
  return;
}

sub select_sql_label {
  my $self = shift;
  my $lists = shift;
  my $sql   = shift;
  my $select_labels = shift;

  if ($self->{LOGGER}) {
    $self->{LOGGER}->warn($sql);
    $self->{LOGGER}->warn(\@_) if @_;
  }

  my $sth = $self->{DBH}->prepare($sql);
  my $err = $self->execute_sth($sth, @_);
  return $sql_err->($sql, $err) if $err;
 
#  if ($types) {
#    my $n = scalar @$types;
#    for my $i (1..$n) {
#      $sth->bind_col($i, undef, {TYPE=>SQL_NUMERIC}) if $type->[$i-1];
#    }
#  }
 
  if (ref($lists) eq 'HASH') {
    if ($select_labels) {
      my %row;
      $sth->bind_columns( \( @row{@$select_labels} ));
      $sth->fetch;
      $lists->{$_} = $row{$_} for (keys %row);
    } else {
      my $hash = $sth->fetchrow_hashref();
      $lists->{$_} = $hash->{$_} for (keys %$hash);
    }
  } elsif ($select_labels) {
    my %row;
    $sth->bind_columns( \( @row{@$select_labels} ));
    while ($sth->fetch) { # aliase to fetchrow_arraryref
      push @$lists, {%row};
    }
  } else {
    while (my $hash = $sth->fetchrow_hashref()) { 
#my $n;
#while (my ($k, $v) = each %$hash) {
#  if (looks_like_number($v)) {
#    $n->{$k} = $v+0;
#  } else {
#    $n->{$k} = $v;
#  }
#}
#      push @$lists, $n;
      push @$lists, $hash;
    }
  }

  $sth->finish;
  return;
}

sub do_proc {
  my $self = shift;
  my $hash = shift;

  if (ref($hash) eq 'HASH') {
    my $names = shift;
    my $proc_name = shift;
    return $self->select_do_proc_label(undef, $hash, $names, $proc_name, undef, @_);
  }

  return $self->select_do_proc_label(undef, undef, undef, $hash, undef, @_);
}

sub select_proc {
  my $self = shift;
  my $lists = shift;
  my $proc_name = shift;

  return $self->select_do_proc_label($lists, undef, undef, $proc_name, undef, @_);
}

sub select_proc_label {
  my $self = shift;
  my ($lists, $proc_name, $label, @pars) = @_;

  return $self->select_do_proc_label($lists, undef, undef, $proc_name, $label, @pars);
}

sub select_do_proc {
  my $self = shift;
  my ($lists, $hash, $names, $proc_name, @pars) = @_;

  return $self->select_do_proc_label($lists, $hash, $names, $proc_name, undef, @pars);
}

sub select_do_proc_label {
  my $self = shift;
  my ($lists, $hash, $names, $proc_name, $label, @pars) = @_;

  my $n = scalar(@pars);
  my $str_q = join(',', ('?')x$n);

  my $str;
  my $str_n;
  if ($names) {
    $str_n = join(',', map {'@'.$_} @$names);
    $str = "CALL $proc_name($str_q, $str_n)";
  } else {
    $str = "CALL $proc_name($str_q)";
  }

  if ($self->{LOGGER}) {
    $self->{LOGGER}->warn($str);
    $self->{LOGGER}->warn(\@pars) if @pars;
  }

  my $sth = $self->{DBH}->prepare($str);
  my $err = $self->execute_sth($sth, @pars);
  return $sql_err->($str,$err) if $err;
  if (ref($lists) eq 'ARRAY') {
    my $i = 0;
    while (my $NS = $sth->{NAME}) {
      my $data = [];
      my %row;
      $NS = $label->[$i] if ($label && $label->[$i] && @{$label->[$i]});
      $i++;
      $sth->bind_columns( \( @row{@$NS} ));
      while ($sth->fetch) { # aliase to fetchrow_arraryref
        push @$data, {%row};
      }
      push @$lists, $data;
      last unless $sth->more_results;
    }
  }
  $sth->finish;

  return unless (ref($hash) eq 'HASH');

  $sth = $self->{DBH}->prepare("SELECT $str_n");
  $err = $self->execute_sth($sth) and return $sql_err->("SELECT $str_n", $err);

  my $row = $sth->fetchrow_arrayref();
  my $i=0;
  for (@$names) {
    $hash->{$_} = $row->[$i];
    $i++;
  }
  $sth->finish;

  return;
}

1;
