#!/usr/bin/perl

use lib '.';
use lib '../..';

package Access;
use Digest::HMAC_SHA1;
use MIME::Base64();

use Genelet::Access;
use Genelet::CGI;
our @ISA = qw(Genelet::Access Genelet::CGI);

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
use Test::More tests=>20;

my $a = Access->new(
	secret => "12345",
	coding => "67890",
    probe   => 'probe',
    surface => 'surface',
    redirect => 'http://www.foo.bar/handler?redirect_with_question'
);

$ENV{HTTP_COOKIE} = "x=a; y=b; z=c";
ok($a->get_cookie("y") eq "b", "get cookie");

my $fields = ['name','foo','bar'];
my $str = 'jqutVzfOAbQC0oyS5mc6tlWHo9z5-1i6BZLl4n28ifoaxvETnx_qy3ksObd1tq4GUbw';
ok($a->signature($fields) eq $str, "signature is correct");
my $x = $a->verify_cookie($str);
ok(!$x, "cookie is verified");
my $hash = $a->auth();
is($hash->{'X-Forwarded-Time'}, $a->get_when(), "when ticket issued");
ok($hash->{'X-Forwarded-Group'} eq 'foo|bar', "group value is correct");
is($hash->{'X-Forwarded-Request_Time'}, $a->get_when(), "request time");
ok($hash->{'X-Forwarded-User'} eq 'name', "user is 'name'");

$ENV{REQUEST_URI}  = "http://my.foo.bar/request?z=req_with_quesetion";
$ENV{QUERY_STRING} = "x=a&y=b";
$x = $a->forbid(1024,303,'m');
ok(!$x, "redirect is generated");
$hash = $a->r()->{headers_out};
ok($hash->{'Content-Type'} eq 'text/html; charset=UTF-8', "content type");
ok($hash->{'Location'} eq 'http://www.foo.bar/handler?redirect_with_question?go_uri=http%3A%2F%2Fmy.foo.bar%2Frequest%3Fz%3Dreq_with_quesetion%3Fx%3Da%26y%3Db&go_err=1024&role=m', "redirected url address");
ok($hash->{'Set-Cookie'}->[0] eq 'probe=http%3A%2F%2Fmy.foo.bar%2Frequest%3Fz%3Dreq_with_quesetion%3Fx%3Da%26y%3Db; domain=; path=/', "first cookie");
ok($hash->{'Set-Cookie'}->[1] eq 'surface=0; domain=; path=/; Max-Age=0; Expires=Fri, 01-Jan-1980 01:00:00 GMT', "second cookie");

$a->send_page("abcdefg");
ok(!$x, "normal page");

# stats plus 3600 seconds as the 14th elements
my @stats = (
          2053,
          25624608,
          33204,
          1,
          500,
          500,
          0,
          '7',
          1328269307,
          1303065313,
          1326723775,
          4096,
          8,
          3600
);
$a->send_page("abcdefg",1,@stats);
ok(!$x, "new caching page");
$hash = $a->r()->{headers_out};
ok($hash->{"Last-Modified"} eq "Sun, 17 Apr 2011 18:35:13 GMT", "last modified");
ok($hash->{"Content-Length"} eq "7", "length is 7");
ok($hash->{"Accept-Ranges"} eq "bytes", "accept range");
ok($hash->{"Etag"} eq '"1870020-7-4dab32e1"', "etag");
ok($hash->{"Expires"} eq "Sun, 17 Apr 2011 19:35:13 GMT", "expire");

$ENV{HTTP_IF_MODIFIED_SINCE} = $hash->{"Last-Modified"};
$ENV{HTTP_IF_NONE_MATCH} = $hash->{"Etag"};
$a->send_page("abcdefg",1,@stats);
ok(!$x, "cached page, you should see Status: 304 Not Modified");

exit;
