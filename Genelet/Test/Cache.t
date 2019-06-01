#!/usr/bin/perl

use strict;
use Data::Dumper;
use Test::More tests => 40;
use lib '.';
use lib '../..';
use Genelet::Cache;
use vars qw(%routes);

my $TMP = '/cache/';
my $ROOT = `pwd`;
substr($ROOT, -1, 1) = '';

BEGIN { use_ok('Genelet::Cache'); }

my $components = {
    'campaign' => {
        component=>'campaign',
        pathinfo=>'campaignid',
        action=>'edit',
		tag=>'js',
		type=>'json',
        expire=>[
            ['adv', 'campaign',  'update'],
            ['adv', 'campaign',  'delete'],
            ['adv', 'item',      'insert'],
            ['adv', 'item',      'delete'],
            ['adv', 'item',      'update'],
            ['adv', 'advbelong', 'update'],
            ['adv', 'advchac',   'update']] },
    'item' => {
        component=>'item',
        pathinfo=>'itemid',
        action=>'edit',
        expire=>[
            ['adv', 'item',      'update'],
            ['adv', 'item',      'delete'],
            ['adv', 'creative',  'insert'],
            ['adv', 'creative',  'delete']] },
    'site' => {
        component=>'site',
        pathinfo=>'siteid',
        action=>'edit',
        expire=>[
            ['pub', 'site',      'update'],
            ['pub', 'site',      'delete'],
            ['pub', 'slot',      'insert'],
            ['pub', 'slot',      'delete'],
            ['pub', 'slot',      'update'],
            ['pub', 'pubbelong', 'update'],
            ['pub', 'pubchac',   'update']] },
    'slot' => {
        component=>'slot',
        pathinfo=>'slotid',
        action=>'edit',
        expire=>[
            ['pub', 'slot',      'update'],
            ['pub', 'slot',      'delete'],
            ['pub', 'weight',    'insert'],
            ['pub', 'weight',    'delete']] },
};

%routes = (
  '/cache/' => {
      pathinfo=>'_gmark',
      clientcache=>0,
      timeout=>3600,
      _gmark => {
        page => {
          role=>'web',
          component=>'page',
          pathinfo=>'pageid',
          action=>'ads',
          tag=>'js',
          type=>'js',
          expire=>[
            ['pub', 'page', 'update'],
            ['pub', 'page', 'delete']]
        },
        'pub' => {
          role=>'pub',
          expireall=>'pubid',
          pathinfo=>'pubid/_gmark',
          _gmark => {'site'=>$components->{'site'}, 'slot'=>$components->{'slot'}},
        },
        'adv' => {
          role=>'adv',
          expireall=>'advid',
          pathinfo=>'advid/_gmark',
          _gmark => {'campaign'=>$components->{'campaign'}, 'item'=>$components->{'item'}},
        },
      },
  },
);

my $document_root = $ROOT;
my $script = '/test.fcgi';
my $action_name = 'action';
my $cache = Genelet::Cache->new(
    routes=>\%routes,
    document_root=>$document_root,
    script=>$script,
    action_name=>$action_name);

my $n = scalar(keys %{$cache->metrix()});
my $m = scalar(keys %{$cache->expire()});
my $hash = $cache->expire()->{pub_slot_delete};
my $k = scalar(@$hash);
is($n, 5, "number of caching cases: 5");  
is($m,20, "number of expiring cases: 20"); 
is($k, 2, "number of expiring pub_slot_delete: 2"); 

is($hash->[1]->[0], $TMP, "pub_slot_delete 1: 0");
is($hash->[1]->[3]->[0],'pub', "pub_slot_delete 1: 3");
is($hash->[1]->[4], 'pubid',   "pub_slot_delete 1: 4");
ok((($hash->[1]->[5]->[0] eq 'slot') and ($hash->[1]->[6] eq 'slotid')) or (($hash->[1]->[5]->[0] eq 'site') and ($hash->[1]->[6] eq 'siteid')), "pub_slot_delete 1: 5" . " and " . "pub_slot_delete 1: 6");

$hash = $cache->metrix()->{pub_site_edit};
is($hash->{timeout}, 3600, "pub_site_edit caching time 3600");
is($hash->{clientcache}, 0, "pub_site_edit client caching: 0");
is($hash->{path}->[0], $TMP, "pub_site_edit path: 0");
is($hash->{path}->[1]->[0],'pub', "pub_site_edit path: 1");
is($hash->{path}->[2], 'pubid',   "pub_site_edit path: 2");
is($hash->{path}->[3]->[0],'site',"pub_site_edit path: 3");
is($hash->{path}->[4], 'siteid',  "pub_site_edit path: 4");

is($cache->document_root(), $document_root, "document root: $document_root");
is($cache->script(), $script, "script: $script");
is($cache->action_name(), $action_name, "action_name: $action_name");

ok($cache->has_role($TMP.'page/1_js.js', 'web'), $TMP.'page/1_js.js has role called web');
ok(!$cache->has_role($TMP.'page/1_js.js', 'cache'), $TMP.'page/1_js.js does not have role called cache');
ok(!$cache->has_role($TMP.'page/1_js.js', 'page'), $TMP.'page/1_js.js does not have role called page');
ok(!$cache->has_role($TMP.'page/1_js.js', 'js'), $TMP.'page/1_js.js does not have role called js');
ok(!$cache->has_role($TMP.'page/1_js.js', 'pub'), $TMP.'page/1_js.js does not have role called pub');
ok(!$cache->has_role($TMP.'page/1_js.js', 'adv'), $TMP.'page/1_js.js does not have role called adv');
ok(($cache->rewrite($TMP.'pub/111/site/222/333_e.html') eq $script.'/pub/e/site?'.$action_name.'=edit&siteid=222&pubid=111&_gtype=html') or
($cache->rewrite($TMP.'pub/111/site/222/333_e.html') eq $script.'/pub/e/site?'.$action_name.'=edit&pubid=111&siteid=222&_gtype=html'), "rewrite ok");

my $ARGS = {
	_grole=>'pub',
	_gtag=>'e',
	_gcomponent=>'site',
	_gaction=>'edit',
	_gtype=>'html',
	siteid=>222,
	pubid=>111,
};

$cache->current(['pub', 'site', 'edit']);
mkdir '.'.$TMP;
my ($file, @a) = $cache->cache_file($ARGS);

ok(-d '.'.$TMP."/pub", "pub created");
ok(-d '.'.$TMP."/pub/111", "pub/111 created");
ok(-d '.'.$TMP."/pub/111/site", "pub/111/site created");
is($file, $ROOT.$TMP."pub/111/site/222_e.html", "filename: $file");
ok(!@a, "file is not existing");

my $str = "file content";
ok($cache->write($file, $str), "write ok");
is($cache->read($file), $str, "read ok, file is there");

$cache->current(['pub', 'slot', 'delete']);
my ($f1s, $f2s) = $cache->destroy($ARGS);
ok(!(-e $f1s->[0]), $f1s->[0]." is removed");
ok(!$f2s, "slotid not defined, no unlink");

$cache->current(['pub', 'site', 'edit']);
(my $f1, @a) = $cache->cache_file($ARGS);
$cache->write($f1, $str);
$ARGS->{'_gcomponent'} = 'slot';
$ARGS->{'slotid'} = 333;
$cache->current(['pub', 'slot', 'edit']);
(my $f2, @a) = $cache->cache_file($ARGS);
$cache->write($f2, $str);

ok($cache->expireall()->{pub}, 'role pub has expireall');
ok((-e $f1), $f1." exists.");
ok((-e $f2), $f2." exists.");
my %hash = (pubid => 111);
is(@{$cache->expireall()->{pub}->[0]}, 2, "delete all in ".$cache->expireall()->{pub}->[0]->[0]." using ".$cache->expireall()->{pub}->[0]->[1]."=".$hash{$cache->expireall()->{pub}->[0]->[1]});
$cache->destroyall('pub',%hash);
ok(!(-e $f1), $f1." destroyed.");
ok(!(-e $f2), $f2." destroyed.");

system("rm -rf .".$TMP);

exit;
