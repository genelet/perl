# 1) other: save result if no_relate
# 2) arguments passed into action, the 1st one extra restriction,
# the 2nd the hash storing nextpage's extra, and so on
package Genelet::Model;

#use DBI qw(:utils);
use strict;
use Storable qw(dclone);

use Genelet::Crud;
use vars qw(@ISA);
@ISA = ('Genelet::Crud');

__PACKAGE__->setup_accessors(
  args    => {},
  lists   => [],
  other   => {},
  logger  => undef,
  storage => undef,

  nextpages => {},

  current_key   => undef, # a column name, usually pk 
  current_id_auto=>undef, # an auto increment field name
  key_in        => undef, # delete only, stop if key in other tables
  empties       => 'empties',
  fields        => "fields", 

  insert_pars   => undef, # add a new record
  topics_pars   => undef, # topics, select, search etc. starts here
  edit_pars     => undef, # edit
  update_pars   => undef, # update
  insupd_pars   => undef, # insert updater uniques

  total_force   => 0,     # no total rows returned; 1 yes, if not in query
  sortby        => "sortby",      # default sort according to field_key
  sortreverse   => "sortreverse", # if not null then reverse sort
  pageno        => "pageno",      # e.g. "pageno"
  rowcount      => "rowcount",    # e.g. "rowcount"
  totalno       => "totalno",     # e.g. "totalno"
  maxpageno     => "maxpageno",  # e.g. "maxpageno"
);

my $filtered_fields = sub {
  my ($in, $ref) = @_;
  return $ref unless $in;

  my @as = split ',', $in, -1;
  my $out = [];
  for my $item (@as) {
    push(@$out, $item) if (grep {$item eq $_} @$ref);
  }
  return (@$out) ? $out : $ref;
};

my $get_fv = sub {
  my $args = shift;
  my $pars = shift;

  my $field_values;
  if (ref($pars) eq 'HASH') {
    # key is from web page, value is real table column
    while (my ($k, $v) = each %$pars) {
      $field_values->{$v} = $args->{$k} if defined($args->{$k});
    }
  } elsif (ref($pars) eq 'ARRAY') {
    for (@$pars) {
      $field_values->{$_} = $args->{$_} if defined($args->{$_});
    }
  }
  return $field_values;
};

sub clean_other {
  my $self = shift;

  delete $self->{OTHER};
  $self->{OTHER} = {};
  return;
}

sub another_object {
  my $self = shift;
  my $page = shift;
  my $model = $page->{model};

  my $p = $model->new();
  $p->dbh($self->{DBH}) if $self->{DBH};
  $p->logger($self->{LOGGER}) if $self->{LOGGER};

  my @parts = split /::/, $model, -1;
  pop @parts;
  my $obj = pop @parts;
  my $ref = $self->{STORAGE}->{$obj};
  for my $att (qw(nextpages current_table current_tables current_key current_id_auto key_in fields empties total_force sortby sortreverse pageno rowcount totalno maxpagenoedit_pars update_pars insupd_pars insert_pars topics_pars)) {
    $p->$att(ref($ref->{$att})?dclone($ref->{$att}):$ref->{$att}) if $ref->{$att};
  }

  my @pars = map {$self->{uc $_}} (qw(sortby sortreverse pageno rowcount totalno max_pageno field));
  my $args;
  while (my ($key, $value) = each %{$self->{ARGS}}) {
    $args->{$key} = $value unless (grep {$key eq $_} @pars);
  }
  for (@pars) {
    $args->{$_} = $page->{$_} if (defined $page->{$_});
  } 
  $p->args($args);

  return $p;
}

sub call_once {
  my $self = shift;
  my $page = shift;
  my $extra = shift;

  my $p = $self->another_object($page);
  my $action = $page->{action};
  my $marker = $page->{model};
  $marker =~ s/\:\:/_/g;
  $marker .= "_".$action;
  return if $self->{OTHER}->{$marker};

  my $err = $p->$action($extra, @_);
  return $err if $err;

  my $lists = $p->lists();
  $self->{OTHER}->{$marker} = $lists if ($lists && @$lists);

  if ($p->{OTHER}) {
    $self->{OTHER}->{$_} = $p->{OTHER}->{$_} for keys %{$p->{OTHER}};
  }

  return;
}

sub call_nextpage {
  my $self = shift;
  my $page = shift;
  my $extra = shift;

  return unless @{$self->{LISTS}};

  my $new_extra;
  $new_extra->{$_} = $extra->{$_} for (keys %$extra);

  my $p = $self->another_object($page);
  my $action = $page->{action};

  my $fk = $self->{CURRENT_KEY};
  my $p_fk     = $page->{relate_fk};
  my $p_item   = $page->{relate_item};
  my $p_manual = $page->{manual};

  my $marker = $page->{model};
  $marker =~ s/\:\:/_/g;
  $marker .= "_".$action;

  if ($p_manual) {
    while (my ($key, $value) = each %$p_manual) {
      $new_extra->{$key} = $value;
    }
  }

  if (($p_fk and ref($fk) eq 'ARRAY') or (keys(%$p_item)>1)) {
    return 1042 if ($p_fk and ref($p_fk) ne 'ARRAY');
    for my $item (@{$self->{LISTS}}) {
      if ($p_fk) {
        my $i=0;
        for (@$fk) {
          $new_extra->{$p_fk->[$i]} = $item->{$_} if exists($item->{$_});
          $i++;
        }
      } else {
        while (my ($k, $v) = each %$p_item) {
          $new_extra->{$v} = $item->{$k} if exists($item->{$k});
        }
      }
      my $err = $p->$action($new_extra, @_);
      return $err if $err;

      my $lists = $p->lists();
      $item->{$marker} = $lists if ($lists && @$lists);
    }
    if ($p->{OTHER}) {
	  $self->{OTHER}->{$_} ||= $p->{OTHER}->{$_} for keys %{$p->{OTHER}};
    }
    return;
  }

  my ($k, $v);
  ($k, $v) = %$p_item if (!$p_fk and $p_item);
  for my $item (@{$self->{LISTS}}) {
    if ($p_fk) {
      push(@{$new_extra->{$p_fk}}, $item->{$fk}) if exists($item->{$fk});
    } elsif ($p_item) {
      push(@{$new_extra->{$v}}, $item->{$k}) if exists($item->{$k});
    }
  }
  my $err = $p->$action($new_extra, @_);
  return $err if $err;

  my $lists = $p->lists();
  for my $item (@{$self->{LISTS}}) {
    for (@$lists) {
      if ($p_fk) {
        push(@{$item->{$marker}}, $_) if ($item->{$fk} eq $_->{$p_fk});
      } else {
        push(@{$item->{$marker}}, $_) if ($item->{$k} eq $_->{$v});
      }
    }
  }
  if ($p->{OTHER}) {
    $self->{OTHER}->{$_} ||= $p->{OTHER}->{$_} for keys %{$p->{OTHER}};
  }

  return;
}

sub process_after {
  my $self = shift;
  my $action = shift;
  return unless $self->{NEXTPAGES};
  my $nextpages = $self->{NEXTPAGES}->{$action} or return;

  my $i=0;
  foreach my $page (@$nextpages) {
    my $err = ($page->{relate_fk} || $page->{relate_item}) ? $self->call_nextpage($page, $_[$i]) : $self->call_once($page, $_[$i]);
    return $err if $err;
    $i++;
  }

  return;
}

sub topics {
  my $self = shift;
  my $extra = shift || {};

  my $err;
  my $ARGS = $self->{ARGS};
  my $case = $self->{TOTAL_FORCE};
  my $totalno = $self->{TOTALNO};
  my $pageno  = $self->{PAGENO};
  if ($case && $ARGS->{$self->{ROWCOUNT}} && (!$ARGS->{$pageno} || $ARGS->{$pageno}==1)) {
    unless ($ARGS->{$totalno}) {
      $self->{LISTS} = [];
      $err = $self->total_hash($self->{LISTS}, ['counts'], $extra) and return $err;
      $self->{OTHER}->{$totalno} = $ARGS->{$totalno} = $self->{LISTS}->[0]->{counts};
    }
    $self->{OTHER}->{$self->{MAXPAGENO}} = $ARGS->{$self->{MAXPAGENO}} = int( ($ARGS->{$totalno}-1)/$ARGS->{$self->{ROWCOUNT}} )+1;
  }

  my $fields = $filtered_fields->($ARGS->{$self->{FIELDS}}, $self->{TOPICS_PARS});

  $self->{LISTS} = [];
  $err = $self->topics_hash($self->{LISTS}, $fields, $extra, $self->get_order_string()) and return $err;

  return $self->process_after('topics', @_);
}

sub _get_id_val {
  my $self = shift;
  my $extra = shift;
  my $id = $self->{CURRENT_KEY};

  if (ref($id) eq 'ARRAY') {
    my $val;
    foreach my $item (@$id) {
      if (defined($self->{ARGS}->{$item})) {
        push @$val, $self->{ARGS}->{$item};
      } elsif (defined($extra->{$item})) {
        push @$val, $extra->{$item};
      } else {
        return ($id, undef);
      }
    }
    return ($id, $val);
  }

  if (defined($self->{ARGS}->{$id})) {
    return ($id, $self->{ARGS}->{$id});
  } elsif (defined($extra->{$id})) {
    return ($id, $extra->{$id});
  } else {
    return ($id, undef);
  }
}

sub edit {
  my $self = shift;
  my $extra = shift || {};

  my $ARGS = $self->{ARGS};
  if ($ARGS->{"_gid_url"}) {
    $ARGS->{$self->{CURRENT_KEY}} = $ARGS->{"_gid_url"};
  }
  my ($id, $val) = $self->_get_id_val($extra);
  return [1040, $id] unless defined($val);
      
  my $fields = $filtered_fields->($ARGS->{$self->{FIELDS}}, $self->{EDIT_PARS});

  $self->{LISTS} = [];
  my $err = $self->edit_hash($self->{LISTS}, $fields, $id, $val, $extra);
  return $err if $err;

  return $self->process_after('edit', @_);
}

# use 'extra' to override field_values for selected fields
sub insert {
  my $self = shift;
  my $extra = shift;

  my $field_values = $get_fv->($self->{ARGS}, $self->{INSERT_PARS});
  if ($extra) { # to force some field_values
    while (my ($key, $value) = each %$extra) {
      if (ref($self->{INSERT_PARS}) eq 'HASH') {
        $field_values->{$key} = $value if (grep {$key eq $_} values(%{$self->{INSERT_PARS}}));
      } elsif (ref($self->{INSERT_PARS}) eq 'ARRAY') {
        $field_values->{$key} = $value if (grep {$key eq $_} @{$self->{INSERT_PARS}});
      } elsif ($self->{INSERT_PARS} eq $key) {
        $field_values->{$key} = $value;
      }
    }
  }
  return 1078 unless $field_values;

  my $err = $self->insert_hash($field_values);
  return $err if $err;

  $field_values->{$self->{CURRENT_ID_AUTO}} = $self->last_insertid() if $self->{CURRENT_ID_AUTO};
  $self->{LISTS} = [$field_values];

  return $self->process_after('insert', @_);
}

sub last_insertid {
  my $self = shift;

  return $self->{DBH}->last_insert_id(undef, undef, $self->{CURRENT_TABLE}, $self->{CURRENT_ID_AUTO});
}

sub insupd {
  my $self = shift;
  my $extra = shift;

  my $uniques = $self->{INSUPD_PARS};
  return 1078 unless $uniques;

  my $field_values = $get_fv->($self->{ARGS}, $self->{INSERT_PARS});
  if ($extra) { # to force some field_values
    while (my ($key, $value) = each %$extra) {
      if (ref($self->{INSERT_PARS}) eq 'HASH') {
        $field_values->{$key} = $value if (grep {$key eq $_} values(%{$self->{INSERT_PARS}}));
      } elsif (ref($self->{INSERT_PARS}) eq 'ARRAY') {
        $field_values->{$key} = $value if (grep {$key eq $_} @{$self->{INSERT_PARS}});
      } elsif ($self->{INSERT_PARS} eq $key) {
        $field_values->{$key} = $value;
      }
    }
  }
  return 1078 unless $field_values;

  if (ref($uniques) eq 'ARRAY') {
    for (@$uniques) {
      return 1078 unless defined($field_values->{$_});
    }
  } else {
    return 1078 unless defined($field_values->{$uniques});
  }

  my $upd_field_values = $get_fv->($self->{ARGS}, $self->{UPDATE_PARS});

  
  my $s_hash = '';
  my $err = $self->insupd_hash($field_values, $upd_field_values, $self->{CURRENT_KEY}, $uniques, \$s_hash);
  return $err if $err;

  $field_values->{$self->{CURRENT_ID_AUTO}} = $self->last_insertid() if ($s_hash eq 'insert' and $self->{CURRENT_ID_AUTO});
  $self->{LISTS} = [$field_values];

  return $self->process_after('insupd', @_);
}

sub update {
  my $self = shift;
  my $extra = shift || {};

  my ($id, $val) = $self->_get_id_val($extra);
  return [1040, $id] unless defined($val);

  my $field_values = $get_fv->($self->{ARGS}, $self->{UPDATE_PARS});
  return 1077 unless $field_values;
  if (scalar(keys %$field_values)==1 and defined($field_values->{$id})) {
    $self->{LISTS} = [$field_values];
    return $self->process_after('update', @_);
  }

  my $empties;
  if ($self->{EMPTIES} and $self->{ARGS}->{$self->{EMPTIES}}) {
    my @a = split ',', $self->{ARGS}->{$self->{EMPTIES}}, -1;
    for (@a) {
      $_ =~ s/^\s+//g;
      $_ =~ s/\s+$//g;
    }
    $empties = \@a;
  } 
  my $err = $self->update_hash($field_values, $id, $val, $extra, $empties);
  return $err if $err;

  if (ref($id) eq 'ARRAY') {
    my $i=0;
    for (@$id) {
      $field_values->{$_} = $val->[$i];
      $i++;
    }
  } else {
    $field_values->{$id} = $val;
  }
  $self->{LISTS} = [$field_values];

  return $self->process_after('update', @_);
}

sub existing {
  my $self = shift;
  my ($field, $val, $table) = @_;

  my $backup = $self->{CURRENT_TABLE};
  $self->{CURRENT_TABLE} = $table;
  $self->{LISTS} = [];
  my $err = $self->edit_hash($self->{LISTS}, $field, $field, $val);
  $self->{CURRENT_TABLE} = $backup;
  return $err if $err;

  return 1075 if ($self->{LISTS} && $self->{LISTS}->[0]);

  return;
};

sub delete {
  my $self = shift;
  my $extra = shift || {};

  my ($id, $val) = $self->_get_id_val($extra);
  return [1040, $id] unless defined($val);

  my $err;
  if ($self->{KEY_IN}) {
    while (my ($table, $keyname) = each %{$self->{KEY_IN}}) {
      if (ref($val) eq 'ARRAY') {
        for (@$val) {
          $err = $self->existing($keyname, $_, $table) and return $err;
        }
      } else {
        $err = $self->existing($keyname, $val, $table) and return $err;
      }
    }
  }

  $err = $self->delete_hash($id, $val, $extra) and return $err;

  my $hash;
  if (ref($id) eq 'ARRAY') {
    my $i=0;
    for (@$id) {
      $hash->{$_} = $val->[$i];
      $i++;
    }
  } else {
    $hash->{$id} = $val;
  }
  $self->{LISTS} = [$hash];

  return $self->process_after('delete', @_);
}

sub randomid {
  my $self = shift;
  my ($max, $trials, $field, $table) = @_;

  $max    ||= 4294967295;
  $trials ||= 10;
  $field  ||= $self->{CURRENT_KEY};
  $table  ||= $self->{CURRENT_TABLE};

  my $err;
  while ($trials) {
    $trials--;
    my $val = (ref($max) eq 'ARRAY') ? $max->[0] + int(rand()*($max->[1]-$max->[0])) : int(rand()*$max)+1;
    $err = $self->existing($field, $val, $table) and next;
    $self->{ARGS}->{$field} = $val;
    return;
  }

  return 1076; 
}

sub get_order_string {
  my $self = shift;

  my $ARGS = $self->{ARGS};
  my $column = $ARGS->{$self->{SORTBY}};
  unless ($column) {
    return "";
#    $column = (ref($self->{CURRENT_KEY}) eq 'ARRAY') ? join(',', @{$self->{CURRENT_KEY}}) : $self->{CURRENT_KEY};
  }
  $column = ($self->{CURRENT_TABLES}->[0]->{alias} || $self->{CURRENT_TABLES}->[0]->{name}) . ".$column" if ($self->{CURRENT_TABLES} && $column !~ /\./);
  my $order = "ORDER BY $column";
  $order .= " DESC" if $ARGS->{$self->{SORTREVERSE}};

  my $rowcount = $self->{ROWCOUNT};
  if ($ARGS->{$rowcount}) {
    $ARGS->{$self->{PAGENO}} ||= 1;
    $order .= " LIMIT " . $ARGS->{$rowcount} . " OFFSET " . ($ARGS->{$self->{PAGENO}}-1) * $ARGS->{$rowcount};
  }

  return ($order=~/[;"']/) ? "" : $order;
}

1;
