#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 16;
use lib '.';
use lib '../..';

use constant MSG1=> '__msg1__';
use constant MSG2=> '__msg2__';
use constant MSG3=> '__msg3__';

my $TMP = `pwd`;
substr($TMP, -1, 1) = '';
$TMP .= '/genelet_logger_test';

BEGIN { use_ok('Genelet::Logger'); }

my $logger = Genelet::Logger->new(
  minlevel=>'emergency',
  maxlevel=>'critical',
  filename=>$TMP,
);

is($logger->minlevel(), 0,    "Minimal level is emergency");
is($logger->maxlevel(), 2,    "Maximal level is critical");
is($logger->filename(), $TMP, "Filename is ".$TMP);
ok($logger->is_emergency(),   "emergency will been logged");
ok($logger->is_alert(),       "alert will been logged");
ok($logger->is_critical(),    "critical will been logged");
isnt($logger->is_error(), 1,  "error will not been logged");

$logger->emergency(MSG1());
is(getlast($logger), "[emergency ".$$."]".MSG1(),"emergency logged");
$logger->alert(MSG2());
is(getlast($logger), "[alert ".$$."]".MSG2(),    "alert logged");
$logger->critical(MSG1());
is(getlast($logger), "[critical ".$$."]".MSG1(), "critical logged");
$logger->error(MSG2());
is(getlast($logger), "[critical ".$$."]".MSG1(), "error not logged");
is($logger->current_msg(), MSG1(),               "current mess MSG1");
is($logger->current_level(), 2,                  "current level 2");

$logger->minlevel(0);
$logger->maxlevel(7);
$logger->screen_start();
my $str = "[warn ".$$."]GENELET LOGGER {New Screen}";
is(substr(getlast($logger),0,length($str)), $str, "start screen");

my $fake = $$ + 1;
$logger->alert(MSG3());
my $fit = (getlast($logger) eq "[alert ".$$."]".MSG3());
write_fake(MSG2(), $fake, "alert");
$logger->info(MSG1());
$fit &&= (getlast($logger) eq "[info ".$$."]".MSG1());
write_fake(MSG1());
$fit &&= (getlast($logger) eq MSG1());
ok($fit, "screen caught");

unlink $logger->filename();

exit;

sub write_fake {
  my $msg = shift;
  my $fake = shift;
  my $level = shift;

  local *L;
  open(L, ">>".$logger->filename()) || die $!.": ".$logger->filename();
  if ($fake && $level) {
    print L "[$level $fake]$msg\n";
  } else {
    print L $msg, "\n";
  }
  close(L);

  return;
}

sub getlast {
  my $logger = shift;

  my $lastline;

  local *L;
  open(L, $logger->filename()) || die $!.": ".$logger->filename();
  while (<L>) {
    chomp;
    $lastline  = $_;
  }
  close(L);

  return $lastline;
}

