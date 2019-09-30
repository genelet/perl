package Genelet::Test;

use strict;
use base qw(Test::Class);
use DBI;
use Data::Dumper;
use Genelet::Dispatch;
use Test::More;

use strict;

sub initialize {
  return {};
}

sub setup : Test(setup) {
  my $self = shift;

  my $hash = $self->initialize();
  return unless ($hash && $hash->{data} && $hash->{config} && $hash->{component});
  $self->{CONFIG}    = Genelet::Dispatch::get_hash($hash->{config});
  $self->{DATA}      = Genelet::Dispatch::get_hash($hash->{data});
  $self->{COMPONENT} = Genelet::Dispatch::get_hash($hash->{component});

  my $dbh = DBI->connect(@{$self->{CONFIG}->{Db}}) or return;
  my $name = $self->{DATA}->{name};
  $self->{_model} = $name->new(dbh=>$dbh);
  for my $k (qw(nextpages current_table current_key current_id_auto key_in empties fields insert_pars topics_pars edit_pars update_pars insupd_pars)) {
    $self->{_model}->$k($self->{COMPONENT}->{$k});
  }

  return;
}

sub aa_insert : Test(no_plan) {
  my $self = shift;

  my $lists = $self->{DATA}->{aa_insert};
  my $model = $self->{_model};

  return unless ($lists && $model && $model->{INSERT_PARS});
  my $keyname = $self->{COMPONENT}->{current_key};

  for my $item (@$lists) {
    my $args;
    while (my ($k, $v) = each %$item) {
      $args->{$k} = $v;
    }
    $model->args($args); 
    my $err = $model->insert();
    ok(!$err, "Run insert() is successful: $err");
    next if $err;
	my $id_auto = $self->{COMPONENT}->{current_id_auto};
    if ($id_auto) {
      $args->{$id_auto} = $model->last_insertid();
    }
    delete $model->{ARGS};
  }

  return;
}

sub ab_edit : Test(no_plan) {
  my $self = shift;

  my $lists = $self->{DATA}->{ab_edit};
  my $model = $self->{_model};

  return unless ($lists && $self->{_model} && $model->{EDIT_PARS});
  my $keyname = $self->{COMPONENT}->{current_key};

  my $args  = $lists->[0];
  $model->args($args);
  my $err = $model->edit();
  ok(!$err, "Run edit() for is successful: $err"); 
  return if $err;
  my $item = $model->lists()->[0];
  while (my ($k, $v) = each %{$lists->[1]}) { 
    is($item->{$k}, $v, "Action edit(): value of $k is $v");
  }
  delete $model->{ARGS};

  return;
} 

sub ac_topics : Test(no_plan) {
  my $self = shift;

  my $lists = $self->{DATA}->{ac_topics};
  my $model = $self->{_model};

  return unless ($lists && $self->{_model} && $model->{TOPICS_PARS});
  my $keyname = $self->{COMPONENT}->{current_key};
  my $keyvalue = $lists->[0]->{$keyname};

  my $err = $model->topics();
  ok(!$err, "Run topics() is successful: $err"); 
  next if $err;

  my $results = $model->lists();
  for my $item (@$results) {
    if ($item->{$keyname} eq $keyvalue) {
      while (my ($k, $v) = each %{$lists->[1]}) { 
        is($item->{$k}, $v, "Action topics(): value of $k is $v");
      }
    }
  }
  delete $model->{ARGS};

  return;
} 

sub ad_update : Test(no_plan) {
  my $self = shift;

  my $lists = $self->{DATA}->{ad_update};
  my $model = $self->{_model};

  return unless ($lists && $self->{_model} && $model->{UPDATE_PARS});

  $model->args($lists->[0]);
  my $err = $model->update();
  ok(!$err, "Run update() is successful: $err"); 
  next if $err;
  
  if ($model->{EDIT_PARS}) {
    $err = $model->edit();
    ok(!$err, "Run edit() is successful: $err");
    next if $err;
    my $item = $model->lists()->[0];
    while (my ($k, $v) = each %{$lists->[1]}) {
      is($item->{$k}, $v, "Action update(): value of $k is $v");
    }
  }
  delete $model->{ARGS};

  return;
} 

sub ae_delete : Test(no_plan) {
  my $self = shift;

  my $lists = $self->{DATA}->{ae_delete};
  my $model = $self->{_model};

  return unless ($lists && $self->{_model});

  for my $item (@$lists) {
    $model->args($item);
    my $err = $model->delete();
    ok(!$err, "Run delete() is successful: $err");

    if ($model->{EDIT_PARS}) {
      $err = $model->edit();
      ok(!$err, "Run edit() is successful: $err");
      next if $err;
      my $results = $model->lists();
      is(@$results, 0, "Check delete is successful"); #empty array scaler is 0
    }
    delete $model->{ARGS};
  }

  return;
}

sub af_insupd : Test(no_plan) {
  my $self = shift;

  my $lists = $self->{DATA}->{af_insupd};
  my $model = $self->{_model};
  return unless ($lists && $model && $model->{INSUPD_PARS});

  $model->args($lists->[0]);
  my $err = $model->insupd();
  ok(!$err, "Run insupd() is successful: $err"); 
  next if $err;
  
  if ($model->{EDIT_PARS}) {
    $err = $model->edit();
    ok(!$err, "Run edit() is successful: $err");
    next if $err;
    my $item = $model->lists()->[0];
    while (my ($k, $v) = each %{$lists->[1]}) {
      is($item->{$k}, $v, "Action insupd(): value of $k is $v");
    }
  }
  delete $model->{ARGS};

  return;
}

1;

=pod
name is the model name
aa_inser and ae_delete are for multiple insert and delete records
ab_edit is search by the first item, and expect the second item
ac_topics searches all items; the one with the 1st item key matches the second
ad_update updates by the first item, and expects the seconds
{
	"name":"Gmarket::Admin::Model",
	"aa_insert" : [
	    {"adminid":"30","login":"x","passwd":"y","status":"Yes"},
	    {"adminid":"20","login":"xx","passwd":"xy","status":"Yes"}
	],
	"ab_edit": [
	    {"login":"x"},
	    {"adminid":"30","login":"x","passwd":"y","status":"Yes"}
	],
	"ac_topics": [
	    {"login":"x"},
	    {"adminid":"30","login":"x","passwd":"y","status":"Yes"}
	],
	"ad_update": [
	    {"login":"x", "passwd":"z"},
	    {"adminid":"30","login":"x","passwd":"z","status":"Yes"}
	],
	"ae_delete": [
   	 {"login":"x"},
   	 {"login":"xx"}
	]
}
=cut
