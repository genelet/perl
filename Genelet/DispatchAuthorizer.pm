package Gate;
use Genelet::CGI;
use Genelet::Access;
our @ISA = qw(Genelet::CGI Genelet::Access);

package Anonymous;
use Genelet::CGI;
use Genelet::Access::Anonymous;
our @ISA = qw(Genelet::CGI Genelet::Access::Anonymous);

package Genelet::DispatchAuthorizer;

use strict;
use CGI::Fast qw(:cgi);
use Data::Dumper;
use URI;
use URI::Escape();
use Digest::HMAC_SHA1;
use MIME::Base64();

#use GTop ();
use Genelet::Authorizer;
use Genelet::Cache;
use Genelet::Logger;

use vars qw(%CONTROLLER %DEBUG %ERRORS %ROUTES %ACCESSES);

sub run {
  my %characters = (post_max=>1024*1024*3, @_);

  my $PROJECT = $characters{project} or die "project name must be defined";
  $CGI::POST_MAX = $characters{post_max}; # 3M

  my $error = "";

  my $m;
  for (qw(Config Access::Config)) {
    $m = $PROJECT."::$_";
    eval "require $m";
    $error .= $@ if ($@);
  }
  
  *CONTROLLER = eval '\%'.$PROJECT.'::Config::controller';
  *DEBUG      = eval '\%'.$PROJECT.'::Config::debug';
  *ERRORS     = eval '\%'.$PROJECT.'::Config::errors';
  *ROUTES     = eval '\%'.$PROJECT.'::Config::routes';
  *ACCESSES   = eval '\%'.$PROJECT.'::Access::Config::accesses';

  my $document_root= $characters{document_root};
  my $script_name  = $characters{script_name};

  my $logger = Genelet::Logger->new(%DEBUG) if %DEBUG;
  $logger->emergency($error) if ($logger && $error);

  my %base = (document_root => $document_root, script_name => $script_name);
  $base{logger} = $logger if $logger;
  $base{errors} = \%ERRORS if %ERRORS;
  $base{storage}= $characters{storage} if $characters{storage};
  
  my $gates;
  for my $role (keys %ACCESSES) {
    my $pars  = shift @{$ACCESSES{$role}};
    $pars->{chartags}    ||= $CONTROLLER{chartags};
    $pars->{go_uri_name} ||= $CONTROLLER{go_uri_name} if $CONTROLLER{go_uri_name};
    $pars->{role_name}   ||= $CONTROLLER{role_name} if $CONTROLLER{role_name};
    $pars->{tag_name}    ||= $CONTROLLER{tag_name} if $CONTROLLER{tag_name};
    $gates->{$role} = Gate->new(%$pars, %base);
  }

  my $c = Genelet::Authorizer->new(
	%CONTROLLER, %base,
	project => $characters{project},
	gates   => $gates,
  );

  my $cache = Genelet::Cache->new(
    routes        => \%ROUTES,
    document_root => $document_root,
    script_name   => $script_name,
    action_name   => $CONTROLLER{action_name}) if %ROUTES;
  $c->cache($cache) if $cache;
  
  while (my $r = CGI::Fast->new()) {
    $c->r($r);
    $c->run();
  }

  return;
}

1;
