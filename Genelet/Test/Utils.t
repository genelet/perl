#!/usr/bin/perl

use strict;
use Data::Dumper;
use Test::More tests => 14;
use lib '.';
use lib '../..';
use Genelet::Utils;

my $demography = [
        [2,4,2,4,2,3,3,3,3,4], #30
        ['gender', 'age', 'marriage', 'income', 'children', 'hsize', 'ethnicity', 'education', 'religion', 'occupation']
];
my $data = {gender => 1, age => 5, marriage => 1, income => 10, children => 2,
hsize => 0, ethnicity => 2, education => 5, religion => 6, occupation => 11};

BEGIN { use_ok('Genelet::Utils'); }

my $values = [];
for my $key (@{$demography->[1]}) {
  push @$values, $data->{$key};
}

my $total = bits2total($values, $demography->[0]);
is($total, 794045013, "the real number = 794045013");

my $bits = total2bits($total, $demography->[0]);

my $i=0;
for my $key (@{$demography->[1]}) {
  is($bits->[$i], $data->{$key}, "$key is ".$data->{$key});
  $i++;
}

my $stamp = time();
sleep(1);
my $secret = "aaaaaaaa";
my @all = ("bbbbbbbb","cccccccc","dddddddd");

my $tk = token($stamp, @all);
my $bool = check_token($tk, @all);

is($stamp, get_tokentime($tk), "$stamp is ".get_tokentime($tk));
is($bool, 1, "$tk is $bool");
exit;
