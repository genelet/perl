package Genelet::Why;

use strict;
use CGI qw(:header);
use Genelet::Debugger;

use vars qw(%CONTROLLER %DEBUG);

sub run {
  my %characters = (format=>'html', modules=>'no', @_);

  my $PROJECT = $characters{project} or die "project name must be defined";
  die "script name must be defined" unless $characters{script_name};

  my $error = '';

  my $m = $PROJECT."::Config";
  eval "require $m";
  $error .= $@ if ($@); 

  *CONTROLLER = eval '\%'.$m.'::controller';
  *DEBUG      = eval '\%'.$m.'::debug';
  $error .= $@ if ($@); 

  my $t = Genelet::Debugger->new(
	format=>$characters{format},
	modules=>$characters{modules}, 
  );

  my $r = CGI->new();
  my $action = $r->param('action');

  print $r->header();
  print "<html><body><pre>";

  if ($error) {
    print "error: $error\n";
  } else {
    $CONTROLLER{project} = $PROJECT;
    $CONTROLLER{script_name} = $characters{script_name};
    $t->report(action=>$action, ip=>$ENV{REMOTE_ADDR}, ua=>$ENV{HTTP_USER_AGENT}, controller=>\%CONTROLLER, debug=>\%DEBUG);
  }

  print "</pre></body></html>";

  return;
}

1;
