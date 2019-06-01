#!/usr/bin/perl

use lib '.';
use lib '../..';

package Model;
use Data::Dumper;
use Genelet::Model;
use Genelet::Crud;
use Genelet::SQLite;
our @ISA = qw(Genelet::Model Genelet::Crud Genelet::SQLite);


package main;

use strict;
use warnings;
use DBI;
use Data::Dumper;
use Genelet::Logger;
use Test::More tests=>1035;

BEGIN { use_ok('Genelet::Model'); }

my $dbfile = "lite.db";
unlink $dbfile if (-e $dbfile);
my $table = 'testing';
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","") || die $!;
$dbh->do("CREATE TABLE $table (
id	integer primary key asc,
x,
y
)") || die $!;
END { $dbh->do("DROP TABLE $table"); $dbh->disconnect; unlink $dbfile;}

my $ARGS = {};
my $model = Model->new(dbh=>$dbh, current_table=>$table);
$model->current_key('id');
$model->current_id_auto('id');
$model->insert_pars(['x','y']);

my $err;
for (1...99) {
  $ARGS = {x=>'a',y=>'b'};
  $model->args($ARGS);
  $err = $model->insert();
  ok(!$err, "insert record $_");
  my $lists = $model->lists();
  is($lists->[0]->{id}, $_, "id $_");
}
 
$model->update_pars(['id','x','y']);
for (1...99) {
  $ARGS->{id} = $_;
  $ARGS->{y} = 'c';
  $model->args($ARGS);
  $err = $model->update();
  ok(!$err, "update record $_");
  my $lists = $model->lists();
  is($lists->[0]->{id}, $_, "update id is $_");
  ok($lists->[0]->{y} eq 'c', "update y is c");
}

$model->edit_pars(['id','y']);
for (1...99) {
  $ARGS->{id} = $_;
  $model->args($ARGS);
  $err = $model->edit();
  ok(!$err, "edit record $_");
  my $lists = $model->lists();
  is($lists->[0]->{id}, $_, "id $_");
  is($lists->[0]->{y}, 'c', "y is c");
}

$ARGS->{rowcount} = 20;
$model->args($ARGS);
$model->topics_pars(['id','x','y']);
$model->total_force(-1);
$err = $model->topics();
ok(!$err, "topics");
is($ARGS->{totalno}, 99, "total is 99");
is($ARGS->{maxpageno}, 5, "5 pages");
my $lists = $model->lists();
for (1..20) {
  is($lists->[$_-1]->{id}, $_, "topic $_");
}

$ARGS = {pageno=>3, rowcount=>20};
$model->args($ARGS);
$err = $model->topics();
ok(!$err, "topics");
$lists = $model->lists();
for (1..20) {
  is($lists->[$_-1]->{id}, 40+$_, "topic 40+$_");
}

for (1...99) {
  $ARGS->{id} = $_;
  $model->args($ARGS);
  $err = $model->delete();
  ok(!$err, "delete record $_");
  my $lists = $model->lists();
  is($lists->[0]->{id}, $_, "id $_");
}

exit;
