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
use Test::More tests=>8;

my $r = CGI->new();
$r->param(-name=>'action', -value=>'insert');

my $a = Ticket->new(
    r=>$r,
	secret => "12345",
	coding => "67890",
    probe   => 'probe',
    surface => 'surface',
    redirect => 'http://www.foo.bar/handler?redirect_with_question'
);

my $fields = ['name','foo','bar'];
my $str = 'jqutVzfOAbQC0oyS5mc6tlWHo9z5-1i6BZLl4n28ifoaxvETnx_qy3ksObd1tq4GUbw';
$ENV{HTTP_COOKIE} = "x=a; y=b; z=c; probe=http://strange.foo.bar/?aa=bb; surface=$str";

$a->handler_logout();
my $x = $a->r()->{headers_out};
ok($x->{"Location"} eq "/", "logout to");
ok($x->{"Set-Cookie"}->[0] eq "surface=0; domain=; path=/; Max-Age=0; Expires=Fri, 01-Jan-1980 01:00:00 GMT", "clear first cookie");
ok($x->{"Set-Cookie"}->[1] eq "probe=0; domain=; path=/; Max-Age=0; Expires=Fri, 01-Jan-1980 01:00:00 GMT", "clear second cookie");

my $uri = "/a?y=z";
$a->out_pars($fields);
$x = $a->handler_fields($uri);
ok(!$x, "handler fields");
$x = $a->r()->{headers_out};
ok($x->{"Set-Cookie"}->[2] eq "surface=$str; domain=; path=/", "login cookie is set");

my $login = "login";
my $password = "password";

$x = $a->authenticate($login, $password, $fields, $uri);
is($x,1031,"default missed");

$login = "hello";
$password = "world";
$x = $a->authenticate($login, $password, $fields, $uri);
ok(!$x, "default login");
ok($fields->[2] eq 'hello', 'login name is correct');

exit;
