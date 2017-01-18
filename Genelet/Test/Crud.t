#!/usr/bin/perl

use lib '.';
use lib '../..';

package Crud;
use Data::Dumper;
use Genelet::Model;
use Genelet::Crud;
use Genelet::SQLite;
our @ISA = qw(Genelet::Model Genelet::Crud Genelet::SQLite);

sub new {
  my ($class, %args) = @_;
  my $self = {};

  $self->{CURRENT_TABLE} = $args{current_table};
  $self->{DBH}           = $args{dbh};
  $self->{LOGGER}        = $args{logger};

  bless $self, $class;
  return $self;
}


package main;

use strict;
use warnings;
use DBI;
use Data::Dumper;
use Genelet::Logger;
use Test::More tests=>24;

use constant TMP => '/tmp/genelet_logger_test';

BEGIN { use_ok('Genelet::Crud'); }

my $logger = Genelet::Logger->new(
  minlevel=>'emergency',
  maxlevel=>'debug',
  filename=>TMP(),
);

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

my $crud = Crud->new(dbh=>$dbh, current_table=>$table, logger=>$logger);
my $err = $crud->guess_fields();
ok(!$err, "no error found in guessing fields");
my $cols = $crud->guessed();
ok($cols->[0] eq 'id' && $cols->[1] eq 'x' && $cols->[2] eq 'y', "get columns");

my $hash = {x=>'a',y=>'b'};
$err = $crud->insert_hash($hash);
ok(!$err, "no error found for insert");
my $id = $crud->last_insertid();
is($id, 1, "id is 1");

$hash = {x=>'c',y=>'d'};
$err = $crud->insert_hash($hash);
ok(!$err, "no error found for 2nd insert");
$id = $crud->last_insertid();
is($id, 2, "id is 2");

$err = $crud->update_hash({y=>'z'}, 'id', $id);
ok(!$err, "no error found for update");

my $lists = [];
$err = $crud->edit_hash($lists, ['x','y'], 'id', $id);
ok(!$err, "no error found for edit hash");
is(@$lists, 1, "edit returns 1 row");
is($lists->[0]->{x}, 'c', "X is 'c'");
is($lists->[0]->{y}, 'z', "Y is 'z'");

$lists = [];
$err = $crud->topics_hash($lists, ['x','y']);
ok(!$err, "no error found for topics");
is(@$lists, 2, "topics returns 2 rows");
is($lists->[0]->{x}, 'a', "first row X is 'a'");
is($lists->[0]->{y}, 'b', "first row Y is 'b'");

$err = $crud->delete_hash('id',1);
ok(!$err, "no error found for delete the first row");

$lists = [];
$err = $crud->topics_hash($lists, ['id','x','y']);
ok(!$err, "no error found for topics after deleting the first row");
is(@$lists, 1, "topics returns 1 row");
is($lists->[0]->{id}, '2', "first row id is 2");
is($lists->[0]->{x}, 'c', "first row X is 'c'");
is($lists->[0]->{y}, 'z', "first row Y is 'z'");

$hash = {id=>2,x=>'a',y=>'b'};
$err = $crud->insert_hash($hash);
is($err, 1171, "catch error 1171: execute failed in inserted, see logger.");

$err = $crud->update_hash({z=>'zz'}, 'id', 3);
is($err, 1074, "catch error 1074: do failed in updated, see logger.");

exit;
