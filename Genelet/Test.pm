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
  my $model = $self->{DATA}->{model};
  $self->{_model} = $model->new(dbh=>$dbh);
  for my $k (qw(nextpages current_table current_key current_id_auto key_in empties fields insert_pars topics_pars edit_pars update_pars insupd_pars)) {
    $self->{_model}->$k($self->{COMPONENT}->{$k});
  }

  my $filter = $self->{DATA}->{filter};
  $self->{_filter} = $filter->new(ACTIONS=>$self->{COMPONENT}->{actions});

  return;
}

sub bf_after : Test(no_plan) {
  my $self = shift;
  my $lists = $self->{DATA}->{bf_after};
  return unless ($lists);

  my $filter = $self->{_filter};
  my $form = $self->{_model};
  for my $item (@$lists) {
    my $OTHER = $item->{other};
    if ($OTHER && @$OTHER) {
      $form->{OTHER} = $OTHER;
    }
    my $LISTS = $item->{lists};
    if ($LISTS && @$LISTS) {
      $form->{LISTS} = $LISTS;
    }
    $filter->args($item->{input});
    my $err = $filter->after($form);
    ok(!$err, "Run after() is successful: $err");
    my $ARGS = $filter->args();
    while (my ($k, $v) = each %{$item->{output}}) {
      is($ARGS->{$k}, $v, "after(): value of $k is $v");
    }
    delete $filter->{ARGS};
  }
  
  return;
}

sub be_after_fail : Test(no_plan) {
  my $self = shift;
  my $lists = $self->{DATA}->{be_after_fail};
  return unless ($lists);

  my $filter = $self->{_filter};
  my $form = $self->{_model};
  for my $item (@$lists) {
    my $OTHER = $item->{other};
    if ($OTHER && @$OTHER) {
      $form->{OTHER} = $OTHER;
    }
    my $LISTS = $item->{lists};
    if ($LISTS && @$LISTS) {
      $form->{LISTS} = $LISTS;
    }
    $filter->args($item->{input});
    my $err = $filter->after($form);
    is($err, $item->{output}, "Run after() negative is successful: $err");
    delete $filter->{ARGS};
  }
  
  return;
}

sub bd_before : Test(no_plan) {
  my $self = shift;
  my $lists = $self->{DATA}->{bd_before};
  return unless ($lists);

  my $filter = $self->{_filter};
  my $form = $self->{_model};
  for my $item (@$lists) {
    my $extra = {};
    my $nextextras = [];
    $filter->args($item->{input});
    my $err = $filter->before($form, $extra, $nextextras);
    ok(!$err, "Run before() is successful: $err");
    my $ARGS = $filter->args();
    while (my ($k, $v) = each %{$item->{output}}) {
      is($ARGS->{$k}, $v, "before(): value of $k is $v");
    }
	if ($item->{extra}) {
      while (my ($k, $v) = each %{$item->{extra}}) {
        is($extra->{$k}, $v, "before(): extra $k is $v");
      }
    }
	if ($item->{nextextras}) {
      for (my $i=0; $i<length(@{$item->{nextextras}}); $i++) {
        while (my ($k, $v) = each %{$item->[$i]->{nextextras}}) {
          is($nextextras->[$i]->{$k}, $v, "before(): nextextras of $i, $k is $v");
        }
      }
    }
    delete $filter->{ARGS};
  }
  
  return;
}

sub bc_before_fail : Test(no_plan) {
  my $self = shift;
  my $lists = $self->{DATA}->{bc_before_fail};
  return unless ($lists);

  my $filter = $self->{_filter};
  my $form = $self->{_model};
  for my $item (@$lists) {
    $filter->args($item->{input});
    my $err = $filter->before($form, {}, []);
    is($err, $item->{output}, "Run before() negative is successful: $err");
    delete $filter->{ARGS};
  }
  
  return;
}

sub bb_preset : Test(no_plan) {
  my $self = shift;
  my $lists = $self->{DATA}->{bb_preset};
  return unless ($lists);

  my $filter = $self->{_filter};
  for my $item (@$lists) {
    $filter->args($item->{input});
    my $err = $filter->preset();
    ok(!$err, "Run preset() is successful: $err");
    my $ARGS = $filter->args();
    while (my ($k, $v) = each %{$item->{output}}) {
      is($ARGS->{$k}, $v, "preset(): value of $k is $v");
    }
    delete $filter->{ARGS};
  }
  
  return;
}

sub ba_preset_fail : Test(no_plan) {
  my $self = shift;
  my $lists = $self->{DATA}->{ba_preset_fail};
  return unless ($lists);

  my $filter = $self->{_filter};
  for my $item (@$lists) {
    $filter->args($item->{input});
    my $err = $filter->preset();
    is($err, $item->{output}, "Run preset() negative is successful: $err");
    delete $filter->{ARGS};
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
    $model->args($item); 
    my $err = $model->insert();
    ok(!$err, "Run insert() is successful: $err");
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
model: is the model package name
filter: is the filter package name
aa_inser and ae_delete: for multiple insert and delete records
ab_edit: search by the first item, and expect the second item
ac_topics: searches all items; the one with the 1st item key matches the second
ad_update: updates by the first item, and expects the seconds
ba_preset_fail: fail in preset, input args=>error
bb_preset: in preset, input args=>output args
bc_before: fail in before, input args=>error
bd_before: in before, input args=>output args, "extra" hash, and "nextextra" arrays of hash
be_after_fail: fail in after, input args, lists, other=>error
bf_after: in after, input args, lists, other=>output hash
{
"model":"Gmarket::Admin::Model",
"filter":"Gmarket::Admin::Filter",
"aa_insert" : [
	{"adminid":"ACCOUNTING","login":"x","passwd":"y","status":"Yes"},
	{"adminid":"ACCOUNTING","login":"xx","passwd":"xy","status":"Yes"}
],
"ab_edit": [
	{"login":"x"},
	{"adminid":"ACCOUNTING","login":"x","passwd":"y","status":"Yes"}
],
"ac_topics": [
	{"login":"x"},
	{"adminid":"ACCOUNTING","login":"x","passwd":"y","status":"Yes"}
],
"ad_update": [
	{"login":"x", "passwd":"z"},
	{"adminid":"ACCOUNTING","login":"x","passwd":"z","status":"Yes"}
],
"ae_delete": [
	{"login":"x"},
	{"login":"xx"}
],
"ba_preset_fail": [
	{
		"input":{"adminid":"ACCOUNTING"},
		"output":"wrong privilege"
	},
	{
		"input":{"adminid":"ROOT","adminlogin":"x","login":"x","g_action":"insert"},
		"output":"wrong admin"
	},
	{
		"input":{"adminid":"ROOT","adminlogin":"x","login":"y","groups":["ROOT,ACCOUNTING,SUPPORT"],"g_action":"insert"},
		"output":"wrong privilege"
	},
	{
		"input":{"adminid":"ROOT","adminlogin":"x","login":"y","groups":["ACCOUNTING,SUPPORT"],"passwd":"a_","g_action":"insert"},
		"output":"wrong passwd"
	}
],
"bb_preset": [
	{
		"input":{"adminid":"ROOT","login":"aaaa","passwd":"bbbbbbbbb","groups":["ACCOUNTING","SUPPORT"],"g_action":"insert"},
		"output":{"adminid":"ACCOUNTING,SUPPORT"}
	}
],
"bf_after": [
	{
		"input":{"g_action":"insert","old_adminid":"ROOT"},
		"output":{"g_action":"insert","adminid":"ROOT"}
	}
]
}
=cut
