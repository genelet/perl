#!/usr/bin/perl

use lib '.';
use lib '../..';

use strict;
use warnings;
use CGI;
use Data::Dumper;
use Genelet::Filter;
use Test::More tests=>13;

BEGIN { use_ok('Genelet::Filter'); }

my $ARGS = {};
my %actions = (
  insert    => {groups=>['p'], validate=>['company','email','passwd']},
  edit      => {groups=>['a'], validate=>['memberid']},
  update    => {groups=>['a'], validate=>['memberid']},
  'delete'  => {validate => ['memberid']},
  topics    => {aliases=>['Lists']},
);

my $r = CGI->new();
$r->param(-name=>'action', -value=>'insert');

my $filter = Genelet::Filter->new(r=>$r, args=>$ARGS);

ok($filter->can('preset'), "Preset ok");
ok($filter->can('before'), "Before ok");
ok($filter->can('after'), "After ok");

$filter->actions(\%actions);

$ARGS->{memberid} = 0;
$filter->args($ARGS);
ok(!$filter->validate('edit'), "validate edit");
ok(!$filter->validate('update'), "validate update");
ok(!$filter->validate('topics'), "validate topics not touched");
ok($filter->validate('insert') eq 'company', "company is missing");

my ($action, $hash) = $filter->get_action('action');
ok($action eq 'insert', "action is insert");
ok($hash->{groups}->[0] eq 'p', "group is p");
ok($hash->{validate}->[0] eq 'company', "validate 0 is company");
ok($hash->{validate}->[1] eq 'email', "validate 1 is email");

$r->param(-name=>'action', -value=>'Lists');
($action, $hash) = $filter->get_action('action');
ok($action eq 'topics', "action is topics, alias Lists");

exit;
