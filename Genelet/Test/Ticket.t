#!/usr/bin/perl

use lib '.';
use lib '../..';

package Ticket;
use Digest::HMAC_SHA1;
use MIME::Base64();

use Genelet::Access::Ticket;
use Genelet::CGI;
use Genelet::Template;
our @ISA = qw(Genelet::Access::Ticket Genelet::CGI Genelet::Template);

sub get_when {
  return 1234567;
}

sub get_ip {
  return "123.123.123.123";
}

package main;

use strict;
use warnings;
use Data::Dumper;
use CGI;
use Test::More tests=>4;

my $r = CGI->new();
$r->param(-name=>'action', -value=>'insert');

my $a = Ticket->new(
    r=>$r,
	secret => "12345",
	coding => "67890",
    go_probe_name  => 'probe',
    surface => 'surface',
    script => 'http://www.foo.bar/handler'
);

my $fields = ['name','foo','bar'];
my $str = 'jqutVzfOAbQC0oyS5mc6tlWHo9z5-1i6BZLl4n28ifoaxvETnx_qy3ksObd1tq4GUbw';
$ENV{HTTP_COOKIE} = "x=a; y=b; z=c; probe=http://strange.foo.bar/?aa=bb; surface=$str";

my $uri = "/a?y=z";
my $login = "login";
my $password = "password";

my $x = $a->authenticate($login, $password, $fields, $uri);
is($x,1031,"default missed");

$login = "hello";
$password = "world";
$x = $a->authenticate($login, $password, $fields, $uri);
ok(!$x, "default login ok");
my $out  = $a->out_pars();
my $hash = $a->out_hash();
ok($out->[0] eq 'login', 'login name is correct');
ok($hash->{login} eq 'hello', 'login value is correct');

exit;
