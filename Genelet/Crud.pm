package Genelet::Crud;

use strict;
use Genelet::DBI;

use vars qw(@ISA);
@ISA = ('Genelet::DBI');

__PACKAGE__->setup_accessors(
	guessed => {},
	current_table  => '',
	current_tables => '',
);

my $table_string = sub {
  my $tables = shift;

  my $i = 0;
  my $sql;
  for my $table (@$tables) {
    my $name = $table->{name};
    $name .= " " . $table->{alias} if $table->{alias};
    if ($i==0) {
      $sql = $name;
	} elsif ($table->{using}) {
      $sql .= "\n" . uc($table->{type}) . " JOIN $name USING (" . $table->{using} . ")";
    } else {
      $sql .= "\n" . uc($table->{type}) . " JOIN $name ON (" . $table->{on} . ")";
    }
    $i++;
  }
 
  return $sql;
};

my $select_label_string = sub {
  my $select_pars = shift;

  my $select_labels;
  my $sql;

  if (ref($select_pars) eq 'ARRAY') {
    $select_labels = $select_pars;
    $sql = join(', ', @$select_pars);
  } elsif (ref($select_pars) eq 'HASH') {
    my @columns = sort keys %$select_pars;
    my @labels  = @{$select_pars}{@columns};
    $select_labels = \@labels;
    $sql = join(', ', @columns);
  } else {
    $select_labels = [$select_pars];
    $sql = $select_pars;
  }

  return ($sql, $select_labels);
};

my $select_condition_string = sub {
  my $extra = shift;
  my $table = shift;

  # we can have value to be an arrary ref and be mapped to IN (?,?....?)
  # to be work on this later.......
  my @fields;
  foreach (sort keys %$extra) {
    if (defined($extra->{$_})) {
      push @fields, $_; 
    } else {
      delete $extra->{$_};
    }
  }
  return unless @fields;

  my $sql = "WHERE ";
  my @values;
  my $i=0;
  for my $field (@fields) {
    $sql .= " AND (" if ($i);
    my $fieldfull = $field;
    $fieldfull = $table.".$field" if ($table && $field !~ /\./);
    if (ref($extra->{$field}) eq 'HASH') {
      my $j=0;
      foreach my $key (%{$extra->{$field}}) {
        $sql .= " AND " if ($j); $j++;
        my $val = $extra->{$field}->{$key};
        if (ref($val) eq 'ARRAY') {
          my $n = scalar(@$val);
          $sql .= "$fieldfull $key (" . join(",", ("?")x$n).")"; 
          push @values, @$val;
        } else {
          $sql .= "$fieldfull $key ?"; 
          push @values, $val;
        }
      }
    } elsif (ref($extra->{$field}) eq 'ARRAY') {
      my $n = scalar(@{$extra->{$field}});
      $sql .= "$fieldfull IN (" . join(",", ("?")x$n).")";
      push @values, @{$extra->{$field}};
    } elsif ($field eq '_gsql') {
      $sql .= $extra->{$field};
    } else {
      $sql .= "$fieldfull =?";
      push @values, $extra->{$field};
    }
    $sql .= ")" if ($i);
    $i++;
  }

  return ($sql, @values);
};

my $single_condition_string = sub {
  my ($keyname, $ids, $extra) = @_;

  my $sql = "WHERE";
  my @extra_values;

  if (ref($keyname) eq 'ARRAY') {
    my $i=0;
    for my $item (@$keyname) {
      my $val = $ids->[$i];
      $i++;
      if (ref($val) eq 'ARRAY') {
        my $n = scalar(@$val);
        $sql .= " $item IN (".join(",", ("?")x$n).")";
        push @extra_values, @$val;
      } else {
        $sql .= " AND" if ($i>1);
        $sql .= " $item=?";
        push @extra_values,  $val;
      }
    }
  } else {
    if (ref($ids) eq 'ARRAY') {
      my $n = scalar(@$ids);
      $sql .= " $keyname IN (".join(",", ("?")x$n).")";
      push @extra_values, @$ids;
    } else {
      $sql .= " $keyname=?";
      push @extra_values,  $ids;
    }
  }

  if ($extra) {
    my @extra_fields = sort keys %$extra;
    for (@extra_fields) {
      $sql .= " AND $_=?";
      push @extra_values, $extra->{$_};
    }
  }

  return ($sql, @extra_values);
};

sub insert_hash {
  my $self = shift;
  return $self->_insert_hash("INSERT", @_);
}

sub replace_hash {
  my $self = shift;
  return $self->_insert_hash("REPLACE", @_);
}

sub insupd_hash {
  my $self = shift;
  my ($field_values, $upd_field_values, $keyname, $uniques, $s_hash) = @_;
  
  my $f = (ref($keyname) eq 'ARRAY') ? join(',', @$keyname) : $keyname;
  my $s = "SELECT $f FROM ".$self->{CURRENT_TABLE}."\nWHERE ";
  my @v;
  if (ref($uniques) eq 'ARRAY') {
    $s .= join(" AND ", map { "$_=?" } @$uniques);
    push(@v, $field_values->{$_}) for (@$uniques);
  } else {
    $s .= "$uniques=?";
    push @v, $field_values->{$uniques};
  }

  my $lists = [];
  my $err = $self->select_sql($lists, $s, @v);
  return $err if $err;
  return 1070 if $lists->[1];

  if ($lists->[0]) {
    $err = $self->update_hash($upd_field_values, $uniques, 
	(ref($uniques) eq 'ARRAY') 
	? [map {$field_values->{$_}} @$uniques] 
	: $field_values->{$uniques});
    return $err if $err;
    $$s_hash = 'update';
  } else {
    $err = $self->insert_hash($field_values);
    return $err if $err;
    $$s_hash = 'insert';
  }

  if (ref($keyname) eq 'ARRAY') {
    $field_values->{$_} = $lists->[0]->{$_} for (@$keyname);
  } else {
    $field_values->{$keyname} = $lists->[0]->{$keyname};
  }

  return;
}

sub _insert_hash {
  my ($self, $HOW, $field_values) = @_;

  my @fields;
  my @values;
  foreach (sort keys %$field_values) {
    if (defined($field_values->{$_})) {
      push @fields, $_;
      push @values, $field_values->{$_};
    } else {
      delete $field_values->{$_};
    }
  }

  my $sql = sprintf "$HOW INTO %s (%s) VALUES (%s)", $self->{CURRENT_TABLE}, join(", ", @fields), join(", ", ("?")x@fields);

  return $self->do_sql($sql, @values);
}

sub update_hash {
  my ($self, $field_values, $keyname, $ids, $extra, $empties) = @_;

  if (ref($keyname) eq 'ARRAY') {
    for (@$keyname) {
      delete $field_values->{$_} if defined($field_values->{$_});
    }
  } else {
    delete $field_values->{$keyname} if defined($field_values->{$keyname});
  }
  
  my @fields;
  my @values;
  foreach (sort keys %$field_values) {
    if (defined($field_values->{$_})) {
      push @fields, $_;
      push @values, $field_values->{$_};
    } else {
      delete $field_values->{$_};
    }
  }

  my $sql = sprintf "UPDATE %s SET %s", $self->{CURRENT_TABLE}, join(", ", map { "$_=?" } @fields);

  my @nulls;
  if ($empties) {
    for (@$empties) {
      next if (($_ eq $keyname) or defined($field_values->{$_}));
      push @nulls, $_;
    }
  }
  if (@nulls) {
    $sql .= ", " . join(", ", map {"$_=NULL"} @nulls);
  }

  my ($where, @extra_values) = $single_condition_string->($keyname, $ids, $extra);
  $sql .= "\n$where" if $where;

  return $self->do_sql($sql, @values, @extra_values);
}

sub delete_hash {
  my ($self, $keyname, $ids, $extra) = @_;

  my $sql = "DELETE FROM " . $self->{CURRENT_TABLE};
  my ($where, @extra_values) = $single_condition_string->($keyname, $ids, $extra);
  $sql .= "\n$where" if $where;
 
  return $self->do_sql($sql, @extra_values);
}

sub edit_hash {
  my ($self, $lists, $select_pars, $keyname, $ids, $extra) = @_;

  if (ref($keyname) eq 'ARRAY') {
    for (@$keyname) {
      delete $extra->{$_} if defined($extra->{$_});
    }
  } else {
    delete $extra->{$keyname} if defined($extra->{$keyname});
  }

  my ($sql, $select_labels) = $select_label_string->($select_pars);

  $sql = "SELECT $sql\nFROM ".$self->{CURRENT_TABLE};
  my ($where, @extra_values) = $single_condition_string->($keyname, $ids, $extra);
  $sql .= "\n$where" if $where;
 
  return $self->select_sql_label($lists, $sql, $select_labels, @extra_values);
}

sub topics_hash {
  my ($self, $lists, $select_pars, $extra, $order) = @_;

  my ($sql, $select_labels) = $select_label_string->($select_pars);

# for multiple tables: tables = [{table},]
# {table} = {name=>, type=>, on=>};
  $sql = "SELECT $sql\nFROM ".($self->{CURRENT_TABLES} ? $table_string->($self->{CURRENT_TABLES}) : $self->{CURRENT_TABLE});

  my $table;
  if ($self->{CURRENT_TABLES}) {
    $table = $self->{CURRENT_TABLES}->[0]->{alias} || $self->{CURRENT_TABLES}->[0]->{name};
  } 
  my ($where, @values) = $select_condition_string->($extra, $table);
  $sql .= "\n$where" if $where;
  $sql .= "\n$order" if $order;

  return $self->select_sql_label($lists, $sql, $select_labels, @values);
}

sub total_hash {
  my ($self, $lists, $label, $extra) = @_;

  my $table;
  if ($self->{CURRENT_TABLES}) {
    $table = $self->{CURRENT_TABLES}->[0]->{alias} || $self->{CURRENT_TABLES}->[0]->{name};
  } 
  my ($where, @values) = $select_condition_string->($extra, $table);
  my $sql = "SELECT COUNT(*) \nFROM ".($self->{CURRENT_TABLES} ? $table_string->($self->{CURRENT_TABLES}) : $self->{CURRENT_TABLE});
  $sql .= "\n$where" if $where;

  return $self->select_sql_label($lists, $sql, $label, @values);
}

1;
