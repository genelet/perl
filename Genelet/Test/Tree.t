#!/usr/bin/perl

use strict;
use Data::Dumper;
use Test::More tests => 1;
use lib '.';
use lib '../..';
use Genelet::Tree;

sub get_ref {
	return {
    1=>{pid=>   0,leg=>'L'},
   11=>{pid=>   1,leg=>'L'},
  111=>{pid=>  11,leg=>'L'},
 1111=>{pid=> 111,leg=>'L'},
11111=>{pid=>1111,leg=>'L'},
   22=>{pid=>   1,leg=>'R'},
  222=>{pid=>  22,leg=>'R'},
 2222=>{pid=> 222,leg=>'R'},
  333=>{pid=>  22,leg=>'L'},
 3333=>{pid=> 333,leg=>'L'},

 4444=>{pid=>   0,leg=>'L'},
55555=>{pid=>4444,leg=>'L'},
66666=>{pid=>4444,leg=>'R'}};
}

sub get_fks {
	return [ 
		{fkid=> 1,    fid=>2, FKCOLUMN_NAME=>"memberid", FKTABLE_NAME=>"cart",    current_key=>"cartid",    fk=>"cart__carid",
		              pid=>1, PKCOLUMN_NAME=>"memberid", PKTABLE_NAME=>"member",                            pk=>'member__memberid'},
		{fkid=> 2,    fid=>3, FKCOLUMN_NAME=>"cartid",   FKTABLE_NAME=>"order",   current_key=>"orderid",   fk=>'order__orderod',
					  pid=>2, PKCOLUMN_NAME=>"cartid",   PKTABLE_NAME=>"cart",                              pk=>'cart__carid'},
		{fkid=> 3,    fid=>4, FKCOLUMN_NAME=>"orderid",  FKTABLE_NAME=>"history", current_key=>"historyid", fk=>'history__historyid',
					  pid=>3, PKCOLUMN_NAME=>"orderid",  PKTABLE_NAME=>"order",                             pk=>'order__orderod'},
		{fkid=> 4,    fid=>4, FKCOLUMN_NAME=>"shipid",   FKTABLE_NAME=>"history", current_key=>"historyid", fk=>'history__historyid',
					  pid=>33,PKCOLUMN_NAME=>"shipid",   PKTABLE_NAME=>"ship",                              pk=>'ship__shipid'},
		{fkid=> 5,    fid=>4, FKCOLUMN_NAME=>"companyid",FKTABLE_NAME=>"ship",    current_key=>"shipid",    fk=>'ship__shipid',
					  pid=>33,PKCOLUMN_NAME=>"companyid",PKTABLE_NAME=>"company",                           pk=>'company__companyid'}
	];
}
sub get_fks_ref {
	my $fks = get_fks();
	my $ref = {};
	for (@$fks) {
		push @{$ref->{$_->{fk}}}, $_;
	}
	return $ref;
}

BEGIN { use_ok('Genelet::Tree'); }
my $ref = get_ref();
my @parents = Genelet::Tree::tree_all_parents($ref, 'pid', 1111);
#( [ 111, 1 ], [ 11, 2 ], [ 1, 3 ], [ 0, 4 ] );
is($parents[0]->[0], 111, "value matches");
is($parents[1]->[0], 11, "value matches");
is($parents[2]->[0], 1, "value matches");
is($parents[3]->[0], 0, "value matches");

for (my $i=0; $i<scalar(@parents); $i++) {
	is($parents[$i]->[1], $i+1, "level matches");
}

$ref = get_ref();
# because no child in ref, we first make children (multiple values) for each id
Genelet::Tree::tree_make_children($ref, "pid", "children");
# then we find all children of id=1
my @children = Genelet::Tree::tree_all_children($ref, "children", 1);
# ( [ 11, 1 ], [ 111, 2 ], [ 1111, 3 ], [ 11111, 4 ],
#   [ 22, 1 ], [ 222, 2 ], [ 2222, 3 ],
#              [ 333, 2 ], [ 3333, 3 ]
is($children[0]->[0], 11, "value matches");
is($children[1]->[0], 111, "value matches");
is($children[2]->[0], 1111, "value matches");
is($children[3]->[0], 11111, "value matches");
is($children[4]->[0], 22, "value matches");
is($children[5]->[0], 222, "value matches");
is($children[6]->[0], 2222, "value matches");
is($children[7]->[0], 333, "value matches");
is($children[8]->[0], 3333, "value matches");
is($children[0]->[1], 1, "level matches");
is($children[1]->[1], 2, "level matches");
is($children[2]->[1], 3, "level matches");
is($children[3]->[1], 4, "level matches");
is($children[4]->[1], 1, "level matches");
is($children[5]->[1], 2, "level matches");
is($children[6]->[1], 3, "level matches");
is($children[7]->[1], 2, "level matches");
is($children[8]->[1], 3, "level matches");
# note that although 0 is a parent, it does not appear in ref as a key.
# so we can't get report for 0. The following is empty
# Genelet::Tree::tree_all_children($ref, "children", 0);

$ref = get_fks_ref();
#@parents = Genelet::Tree::tree_hash_parents($ref, 'pk', 'history__historyid');
#warn 11111111111111;
#warn Dumper \@parents;

$ref = get_fks_ref();
warn 11111111111111;
warn Dumper $ref;
@parents = Genelet::Tree::tree_find_parents("member__memberid", $ref, 'pk', 'history__historyid');
warn 22222222222;
warn Dumper \@parents;

$ref = get_fks_ref();
@parents = Genelet::Tree::tree_find_parents("company__companyid", $ref, 'pk', 'history__historyid');
warn 333333333333;
warn Dumper \@parents;

exit;
