package Genelet::Test;

use strict;
use base qw(Test::Class);
use Test::More;

use strict;

sub testing_data { 
  return;
}

sub setup : Test(setup) {
  my $self = shift;

  my $data  = $self->testing_data();
  return unless $data;

  my $class = $data->{class};
  $self->{_model}  = $class->new(dbh=>$self->{_dbh}) if $class;
  $self->{_fields} = $data->{fields};
  $self->{_insert} = $data->{insert};
  $self->{_topics} = $data->{topics};
  $self->{_update} = $data->{update};
  $self->{_edit}   = $data->{edit};

  my $lazy_array = sub {
    my ($fields, $values) = @_;
    my @array;
    for my $item (@$values) {
      my %x;
      @x{@$fields} = @$item;
      push @array, \%x;
    }
    return \@array;
  };

  unless ($self->{_insert}) {
    $self->{_insert} = $lazy_array->($data->{names}, $data->{inserts}) if ($data->{names} and $data->{inserts});
  }
  unless ($self->{_update}) {
    $self->{_update} = $lazy_array->($data->{names}, $data->{updates}) if ($data->{names} and $data->{updates});
  }

  return;
}

sub aa_check_fields : Test(no_plan) {
  my $self = shift;

  return unless ($self->{_fields} and $self->{_model});

  my $model = $self->{_model};
  while (my ($k, $v) = each %{$self->{_fields}}) {
    if (ref($v) eq 'ARRAY') {
      for (my $i=0; $i<scalar(@$v); $i++) {
        is($model->$k()->[$i], $v->[$i], "$k: $v->[$i]");
      }
    } else {
      is($model->$k(), $v, "$k: $v");
    }
  } 

  return;
}
 
sub ab_insert : Test(no_plan) {
  my $self = shift;

  return unless ($self->{_insert} and $self->{_model});
  my $keyname = $self->{_fields}->{current_key};

  $self->{_IDS} = undef;
  my $model = $self->{_model};
  for my $args (@{$self->{_insert}}) {
    $model->args($args); 
    my $err = $model->insert();
    ok(!$err, "Run insert() is successful: $err");
    next if $err;
    if ($self->{_fields}->{current_id_auto}) {
      $args->{$self->{_fields}->{current_id_auto}} = $model->last_insertid();
    }
    push @{$self->{_IDS}}, $args->{$keyname};
  }
  delete $model->{ARGS};

  return;
}

sub ac_edit : Test(no_plan) {
  my $self = shift;

  return unless ($self->{_IDS} and $self->{_model});
  my $keyname = $self->{_fields}->{current_key};

  my $model = $self->{_model};
  my $i=0;
  for my $args (@{$self->{_edit} || $self->{_insert}}) {
    my $id = $self->{_IDS}->[$i];
    $model->args({$keyname => $id});
    my $err = $model->edit();
    ok(!$err, "Run edit() for $keyname = $id is successful: $err"); 
    next if $err;
    my $item = $model->lists()->[0];
    while (my ($k, $v) = each %$args) { 
      is($item->{$k}, $v, "Action edit() for $keyname = $id: value of $k is $v");
    }
    $i++;
  }
  delete $model->{ARGS};

  return;
} 

sub ad_topics : Test(no_plan) {
  my $self = shift;

  return unless ($self->{_IDS} and $self->{_model});
  my $keyname = $self->{_fields}->{current_key};

  my $model = $self->{_model};
  my $err = $model->topics({$keyname => $self->{_IDS}});
  ok(!$err, "Run topics() is successful: $err"); 
  next if $err;

  my $lists = $model->lists();
  my $i=0;
  for my $args (@{$self->{_topics} || $self->{_insert}}) {
    my $item = $lists->[$i];
    while (my ($k, $v) = each %$args) { 
      is($item->{$k}, $v, "Action topics() for $keyname = ".$self->{_IDS}->[$i].": value of $k is $v");
    }
    $i++;
  }
  delete $model->{ARGS};

  return;
} 

sub ae_update : Test(no_plan) {
  my $self = shift;

  return unless ($self->{_IDS} and $self->{_update} and $self->{_model});
  my $keyname = $self->{_fields}->{current_key};

  my $model = $self->{_model};
  my $i=0;
  for my $args (@{$self->{_update}}) {
    my $id = $self->{_IDS}->[$i];
    $args->{$keyname} = $id;
    $model->args($args);
    my $err = $model->update();
    ok(!$err, "Run update() for $keyname = $id is successful: $err"); 
    next if $err;

    $model->args({$keyname => $id});
    $err = $model->edit();
    ok(!$err, "Run edit() for $keyname = $id is successful: $err");
    next if $err;
    my $item = $model->lists()->[0];
    while (my ($k, $v) = each %$args) {
      is($item->{$k}, $v, "Action update() for $keyname = $id: value of $k is $v");
    }
    $i++;
  }
  delete $model->{ARGS};

  return;
} 

sub af_delete : Test(no_plan) {
  my $self = shift;

  return unless ($self->{_IDS} and $self->{_model});
  my $keyname = $self->{_fields}->{current_key};

  my $model = $self->{_model};
  for my $id (@{$self->{_IDS}}) {
    $model->args({$keyname => $id});
    my $err = $model->delete();
    ok(!$err, "Run delete() for $keyname = $id is successful: $err");
  }
  delete $model->{ARGS};

  return;
}

sub ag_insupd : Test(no_plan) {
  my $self = shift;

  my $insupd = $self->{_fields}->{current_insupd};
  return unless ($insupd and $self->{_update} and $self->{_insert} and $self->{_model});
  my $keyname = $self->{_fields}->{current_key};

  $self->{_IDS} = undef;
  my $model = $self->{_model};
  for my $args (@{$self->{_insert}}) {
    $model->args($args);
    my $err = $model->insupd();
    ok(!$err, "Run insupd() insert is successful: $err");
    next if $err;
    if ($self->{_fields}->{current_id_auto}) {
      $args->{$self->{_fields}->{current_id_auto}} = $model->last_insertid();
    }
    push @{$self->{_IDS}}, $args->{$keyname};
  }
  delete $model->{ARGS};

  return unless ($self->{_IDS});

  my $i=0;
  for my $args (@{$self->{_update}}) {
    my $id = $self->{_IDS}->[$i];
    $args->{$keyname} = $id;
    $model->args($args);
    my $err = $model->insupd();
    ok(!$err, "Run insupd() update for $keyname = $id is successful: $err");
    next if $err;

    $model->args({$keyname => $id});
    $err = $model->edit();
    ok(!$err, "Run insupd() edit for $keyname = $id is successful: $err");
    next if $err;
    my $item = $model->lists()->[0];
    while (my ($k, $v) = each %$args) {
      is($item->{$k}, $v, "Action insupd() for $keyname = $id: value of $k is $v");
    }
    $i++;
  }
  delete $model->{ARGS};

  for my $id (@{$self->{_IDS}}) {
    $model->args({$keyname => $id});
    my $err = $model->delete();
    ok(!$err, "Run insupd delete() for $keyname = $id is successful: $err");
  }
  delete $model->{ARGS};

  return;
}

1;
