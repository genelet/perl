#!/usr/bin/perl

use lib '.';
use lib '../..';

use strict;
use warnings;
use CGI;
use Digest::HMAC_SHA1;
use MIME::Base64 qw(encode_base64 decode_base64);
use Genelet::Base;
use Test::More tests=>64;

BEGIN { use_ok('Genelet::Base'); }

my $r = CGI->new();
$r->param(-name=>'action', -value=>'insert');

my ($root, $script, $tmpl) = qw(root script tmpl);
my $base = Genelet::Base->new(r=>$r, document_root=>$root, script=>$script);

ok($base->document_root() eq $root, "getter in document_root");
ok($base->script() eq $script, "getter in script");
$base->template($tmpl);
ok($base->template() eq $tmpl, "setter in template");
my $new_r = $base->r();
ok($new_r->param('action') eq 'insert', "request obj has action 'insert'");

my $key = '1234567';
my $hmac = Digest::HMAC_SHA1->new($key);
$hmac->add($root. $script. $tmpl);
my $digest = MIME::Base64::encode_base64($hmac->digest, '');
ok($digest eq $base->digest64($key, $root, $script, $tmpl), "digest64 is correct");

my %errors  = (
    1000 => "JSON to hash failed.",
	1001 => "Google authorization required.",
	1002 => "Facebook authorization required.",
    1003 => "User denied authorization.",
    1004 => "Failed in browser getting token.",
    1005 => "Failed in browser getting app.",
    1006 => "Failed in browser refreshing token.",
    1007 => "Failed in browser refreshing app.",
    1008 => "Failed in finding token.",
	1009 => "Twitter authorization required.",
    1010 => "Failed in retrieve token secret from db for twitter.",
    1011 => "Failed in getting user_id from twitter.",
    
	1020 => "Login required.",
	1021 => "Not authorized to view the page.",
	1022 => "Login is expired.",
	1023 => "Your IP does not match the login credential.",
	1024 => "Login signature is not acceptable.",

	1030 => "Too many failed logins.",
	1031 => "Login incorrect. Please try again.",
	1032 => "System error.",
	1033 => "Web server configuration error.",
	1035 => "This input field is missing: ",
	1036 => "Please make sure your browser supports cookie.",
	1037 => "Missing input.",

	1040 => "Empty field.",
	1041 => "Foreign key forced but its value not provided.",
	1042 => "Foreign key fields and foreign key-to-be fields do not match.",
	1043 => "Variable undefined in your customzied method.",
	1044 => "Variable undefined in your procedure method.",

	1052 => "Foreign key is broken.",
	1053 => "Foreign key session expired.",
	1054 => "Signature field not found.",
	1055 => "Signature not found.",

	1060 => "Email Server, Sender, From, To and Subject must be existing.",
	1061 => "Message is empty.",
	1062 => "Sending mail failed.",
	1063 => "Mail server not reachable.",

	1071 => "Select Syntax error.",
	1072 => "Failed to connect to the database.",
	1073 => "SQL failed, check your SQL statement; or duplicate entry.",
	1074 => "Die from db.",
	1075 => "Records exist in other tables",
	1076 => "Could not get a random ID.",
	1077 => "Condition not found in update.",

	1080 => "Can't write to cache."
);

for my $code (keys %errors) {
  ok($errors{$code} eq $base->error_str($code), "pass error code $code");
}

for my $code (100000..100009) {
  ok($code eq $base->error_str($code), "pass customized error code $code");
}

my $assigned = {1071=>$root, 1072=>$script, 100000=>$tmpl};
$base->errors($assigned);
for my $code (1071, 1072, 100000) {
  ok($assigned->{$code} eq $base->error_str($code), "pass overriden error code $code");
}


exit;
