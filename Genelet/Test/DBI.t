#!/usr/bin/perl

use lib '.';
use lib '../..';

use strict;
use Data::Dumper;
use Genelet::DBI;

use DBI;
use Test::More tests=>12;

use constant TMP => '/tmp/genelet_logger_test';

BEGIN { use_ok('Genelet::DBI'); }

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

my $dbi = Genelet::DBI->new(dbh=>$dbh);

my $hash = {x=>'a',y=>'b'};
my $err = $dbi->do_sql("INSERT INTO $table (x,y) VALUES ('a','b')");
ok(!$err, "no error found for insert");
$err = $dbi->do_sql("INSERT INTO $table (id,x,y) VALUES (2,'c','d')");
ok(!$err, "no error found for insert");

my $lists = [];
$err = $dbi->select_sql($lists, "SELECT id, x, y FROM $table");
ok(!$err, "no error found for edit hash");
is(@$lists, 2, "edit returns 2 row");
is($lists->[0]->{x}, 'a', "X is 'a'");
is($lists->[0]->{y}, 'b', "Y is 'b'");

$err = $dbi->do_sql("DELETE FROM $table WHERE id=1");
ok(!$err, "no error found for delete the first row");

$lists = [];
$err = $dbi->select_sql($lists, "SELECT id, x, y FROM $table");
ok(!$err, "no error found for edit hash");
is(@$lists, 1, "edit returns 1 row");
is($lists->[0]->{x}, 'c', "X is 'c'");
is($lists->[0]->{y}, 'd', "Y is 'd'");
exit;
