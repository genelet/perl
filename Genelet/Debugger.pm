package Genelet::Debugger;

use strict;
use warnings;
use Data::Dumper;
use URI::Escape;
use Test::More;
use Genelet::Logger;

sub new {
  my ($class, %args) = @_;
  my $self  = {};

  $self->{FORMAT}  = $args{format}  || 'text';
  $self->{MODULES} = $args{modules} || 'standard';

  bless $self, $class;
  return $self;
}

sub format {
  my $self = shift;

  $self->{FORMAT} = shift if (@_);
  return $self->{FORMAT};
}

sub modules {
  my $self = shift;

  $self->{MODULES} = shift if (@_);
  return $self->{MODULES};
}

sub log_test {
  my $self = shift;

  my $metrix    = shift;
  my $script_name = shift;
  my $project   = shift;
  my $actionname= shift;
  my $action    = shift;

  unless ($metrix && $metrix->{METHOD} && $metrix->{URI}) {
    print "No record.\n";
    return;
  }

  my ($component, $tag, $role);
  my ($path, $query) = split /\?/, $metrix->{URI}, -1;
  substr($path, 0, length($script_name)) = "";
  if ($path) {
    my @pathes = split(/\//,  $path, -1);
    $component = pop(@pathes) if @pathes;
    $tag       = pop(@pathes) if @pathes;
    $role      = pop(@pathes) if @pathes;
  } 
  if (!$action && $query) {
    foreach my $part (split('&', $query, -1)) {
      if ($part =~/^$actionname=(.*)$/) {
        $action = $1;
        last;
      }
    }
  }
  $action ||= ($metrix->{METHOD} eq 'POST') ? $metrix->{Controller}->{Name}->{action}->[0] : 'topics';
  $component = ucfirst($component);
  substr($metrix->{URI},-1,1)='' if (substr($metrix->{URI},-1,1) eq '?');
   
  print '"', $metrix->{METHOD}, " ", $metrix->{URI}, "\"\n";
  print "started on ", scalar localtime($metrix->{TIME}), " (", s2dhms(time()-$metrix->{TIME}), " ago)\n";
  print "from ", $metrix->{IP}, ", using ", $metrix->{UA}, "\n";

  if ($metrix->{Loginout} && $metrix->{Loginout}->{OK}->{start}) {
    print "... processing login or logout ...\n\n";
    $self->loginout($metrix);
  } elsif ($metrix->{Authorize} && $metrix->{Authorize}->{Static}) {
    print "... processing authorize static file ...\n\n";
    $self->authorize($metrix);
  } elsif ($metrix->{Authorize}) {
    if ($metrix->{Controller}) {
      print "... processing program with role ...\n\n";
    } else {
      print "... processing access control ...\n\n";
    }
    ok(1, "role \"".$metrix->{Authorize}->{Name}->{role}->[0]."\" is challenged");
    ok($metrix->{Authorize}->{Program}->{end}->[0], "access control started and succeeded") or $self->blue("broken signature");
    $metrix->{Authorize}->{Name}->{user}
        ? ok(1, "remote user \"".uri_unescape($metrix->{Authorize}->{Name}->{user}->[0])."\" accepted.")
        : ok(1, "ENV does not pass in a remote user.");
    $self->controller($metrix, $project, $component, $action, $role, $tag) if $metrix->{Controller};
  } elsif ($metrix->{Controller}) {
    print "... processing program without role ...\n\n";
    $self->controller($metrix, $project, $component, $action, $role, $tag);
  }

  return;
}

sub authorize {
  my ($self, $metrix) = @_;

  if ($metrix->{Authorize}->{Name}->{role}) {
    ok ($metrix->{Authorize}->{Static}->{end}->[0], "\"".$metrix->{Authorize}->{Name}->{role}->[0]."\" authorized.") or failed1("role \"".$metrix->{Authorize}->{Name}->{role}->[0]."\" not authorized");
  } else {
    return failed("role not matched, authorization rejected");
  }
  if ($metrix->{Authorize}->{Ticket}->{start}->[0] && $metrix->{Authorize}->{Ticket}->{end}->[0]) {
    ok(!$metrix->{Authorize}->{Ticket}->{end}->[1], "ticket verified with signature") or $self->blue("invalid ticket");
  }
  if ($metrix->{Authorize}->{PPV}) {
    ok($metrix->{Authorize}->{PPV}->{OK}->[0], "ppv accepted for '".$metrix->{Authorize}->{Name}->{login}->[0]."'");
  }
  if ($metrix->{Authorize}->{Redirect}) {
    ok($metrix->{Authorize}->{Redirect}->{url}->[0], "internal redirect to ".$metrix->{Authorize}->{Redirect}->{url}->[1]);
  }

  return; 
}

sub loginout {
  my ($self, $metrix) = @_;

  if ($metrix->{Loginout}->{In}) {
    ok($metrix->{Loginout}->{In}->{end} && $metrix->{Loginout}->{Name}, "login processed for role \"".$metrix->{Loginout}->{Name}->{role}->[0]."\"") or $self->blue("login process");
    if ($metrix->{Loginout}->{Case}) {
      ok($metrix->{Loginout}->{Case}, "check login case");
      ok(1, "direct login") if $metrix->{Loginout}->{Case}->{direct};
      ok($metrix->{Loginout}->{Case}->{probe}->[0] && !$metrix->{Loginout}->{Case}->{probe}->[1], "probing cookie") if $metrix->{Loginout}->{Case}->{probe};
      ok(1, "login case:".$metrix->{Loginout}->{Case}->{code}->[0]) if $metrix->{Loginout}->{Case}->{code};
    }
    my $oauth = $metrix->{Oauth} || $metrix->{Oauth2};
    ($metrix->{Loginout}->{Authenticate} && !$oauth)
        ? ok($metrix->{Loginout}->{Authenticate}->{start} && $metrix->{Loginout}->{Authenticate}->{end} && !$metrix->{Loginout}->{Authenticate}->{end}->[1], '"'.$metrix->{Loginout}->{Name}->{login}->[0].'" is authenticated:') || $self->blue("user account or algorithm")
        : ok(1, $oauth ? "oauth started" : "login screen is displayed");
    if ($oauth && $oauth->{Authorize}) {
      ok(1, "authorize against ".$oauth->{Authorize}->{URL}->[0]);
      ok(!$oauth->{Authorize}->{end}->[1], "authorize resulted ".$oauth->{Authorize}->{end}->[1]);
    } elsif ($oauth && $oauth->{RequestToken}) {
      ok(1, "requested token against ".$oauth->{RequestToken}->{URL}->[0]);
      ok(!$oauth->{RequestToken}->{end}->[1], "got request token ".$oauth->{RequestToken}->{end}->[1]);
    } elsif ($oauth && $oauth->{AccessToken}) {
      ok(!$oauth->{AccessToken}->{end}->[1], , "got access token ".$oauth->{AccessToken}->{end}->[1]);
      ok(!$oauth->{EndPoint}->{end}->[1], , "got end point ".$oauth->{EndPoint}->{end}->[1]) if $oauth->{EndPoint};
    }
    if ($metrix->{Oauth12}->{Provider}) {
      ok(1, $metrix->{Oauth12}->{Provider}->{code}->[1] ? "new sesion" : "session already generated") if $metrix->{Oauth12}->{Provider}->{code};
      ok(1, "missing ".$metrix->{Oauth12}->{Provider}->{Missing}->[0]) if $metrix->{Oauth12}->{Provider}->{Missing};
      ok(1, "SQL to be run: ".$metrix->{Oauth12}->{Provider}->{SQL}->[0]);
    }
    if ($metrix->{Loginout}->{DBI}) {
      ok(1, "database authentication started") if $metrix->{Loginout}->{DBI}->{start};
      return $self->blue("missing DSN or SQL") if $metrix->{Loginout}->{DBI}->{system};
      if ($metrix->{Loginout}->{DBI}->{check_block}) {
        ok(!$metrix->{Loginout}->{DBI}->{check_block}->[1], "checking block") or return $self->blue("SQL failed");
      }
      ok($metrix->{Loginout}->{DBI}->{end} && !$metrix->{Loginout}->{DBI}->{end}->[1], "account verified") || (($metrix->{Loginout}->{DBI}->{end}->[1]==1032)?$self->red("SQL is wrong"):($metrix->{Loginout}->{DBI}->{end}->[1]==1031)?$self->red("Wrong credentials"):($metrix->{Loginout}->{DBI}->{end}->[1]==1033)?$self->red("SQL server error"):$self->blue("login failed, try again"));
      if ($metrix->{Loginout}->{DBI}->{remove_block}) {
        ok(!$metrix->{Loginout}->{DBI}->{remove_block}->[1], "removing block") or return $self->blue("SQL failed");
      }
      if ($metrix->{Loginout}->{DBI}->{add_block}) {
        ok(!$metrix->{Loginout}->{DBI}->{add_block}->[1], "adding block") or return $self->blue("SQL failed");
      }
    }
    ok(1, "cookie session") if ($metrix->{Loginout}->{Signature} && $metrix->{Loginout}->{Signature}->{cookie});
    ok(1, "url session") if ($metrix->{Loginout}->{Signature} && $metrix->{Loginout}->{Signature}->{url});
  }
  if ($metrix->{Loginout}->{Out}) {
    ok($metrix->{Loginout}->{Out}->{start}->[0] && $metrix->{Loginout}->{Out}->{end}->[0], "logout processed") or return($self->red("logout process"));
    ok(1, "role is \"".$metrix->{Loginout}->{Name}->{role}->[0]."\"");
  }
  fail("login or logout failed or unknown.") if $metrix->{Loginout}->{OK}->{fail};

  return;
}

sub controller {
  my ($self, $metrix, $project, $component, $action, $role, $tag) = @_;

  is($metrix->{Controller}->{Name}->{project}->[0], $project, "project is \"$project\"") or return($self->red("project and script/handler names are correct"));
  ok($metrix->{Controller}->{OK}->{'good url'}->[0], "url is good") or return($self->red("the format of requesting URL"));
  is($metrix->{Controller}->{Name}->{role}->[0], $role, "role is \"$role\"") or return($self->red("role in URL"));
  is($metrix->{Controller}->{Name}->{tag}->[0], $tag, "tag is \"$tag\"") or return($self->red("tag in URL"));
  is($metrix->{Controller}->{Name}->{component}->[0], $component, "component is \"$component\"") or return($self->red("component in URL"));
  ok($metrix->{Controller}->{OK}->{'component list'}->[0], "\"$component\" is in the component list") or return($self->red("your component list"));
  ok($metrix->{Controller}->{Filter}->{'start'}->[0] && $metrix->{Controller}->{Filter}->{'end'}->[0], "filter \"$project"."::".$component."::Filter\" created") or return($self->red("can't initiate $project"."::".$component."::Filter", "$project"."::".$component."::Filter"));
  is($metrix->{Controller}->{Name}->{action}->[0], $action, "action is \"$action\"") or return($self->red("\%actions in $project"."::".$component."::Filter"));
  ok($metrix->{Controller}->{Group}->{start}->[0] && $metrix->{Controller}->{Group}->{end}->[0], "\"$role\" is able to run \"$action\"") or return($self->red("group access in action metrix for $role"));
  if ($metrix->{Controller}->{Upload}) {
    ok($metrix->{Controller}->{Upload}->{end}->[0] && !$metrix->{Controller}->{Upload}->{end}->[1], "file upload succeeded") or return($self->red("name of uploaded field, directory ownership for ".$metrix->{Controller}->{Upload}->{end}->[1]));
  }
  if ($metrix->{Controller}->{FKin}) {
    ok($metrix->{Controller}->{FKin}->{start}->[0] && $metrix->{Controller}->{FKin}->{end}->[0] && !$metrix->{Controller}->{FKin}->{end}->[1], "checking foreign key, started and completed") || return($self->red("if correct key and md5 were passed, the first 2 element in FKS in $project"."::$component"."::Filter"));
  }
  if ($metrix->{Controller}->{Cache} && $metrix->{Controller}->{Cache}->{sending}) {
    is($metrix->{Controller}->{Name}->{cachecase}->[0], 'retrieve', 'retrieve from cache');
    ok($metrix->{Controller}->{Cache}->{sending}->[0] && !$metrix->{Controller}->{Cache}->{sending}->[1], "sending cached page");
    return;
  }
  ok($metrix->{Controller}->{Preset}->{start}->[0] && $metrix->{Controller}->{Preset}->{end}->[0] && !$metrix->{Controller}->{Preset}->{end}->[1], "\"preset\" started and completed") or return($self->red("$project"."::".$component."::Filter::preset"));
  $metrix->{Controller}->{DB}
    ? ok($metrix->{Controller}->{DB}->{start}->[0] && $metrix->{Controller}->{DB}->{end}->[0], "database handler created") || return($self->red("database connection account is incorrect"))
    : ok(1, "DB: not applied");
  ok($metrix->{Controller}->{Model}->{'start'}->[0] && $metrix->{Controller}->{Model}->{'end'}->[0], "model \"$project"."::".$component."::Model\" created") or return($self->red("can't initiate $project"."::".$component."::Model", "$project"."::".$component."::Model"));
  ok($metrix->{Controller}->{Before}->{start}->[0] && $metrix->{Controller}->{Before}->{end}->[0] && !$metrix->{Controller}->{Before}->{end}->[1], "\"before\" started and completed") or return($self->red("$project"."::".$component."::Filter::before"));
  $metrix->{Controller}->{Action} 
    ? ok($metrix->{Controller}->{Action}->{start}->[0] && $metrix->{Controller}->{Action}->{end}->[0] && !$metrix->{Controller}->{Action}->{end}->[1], "run \"$action\", started and completed") || return($self->red("$project"."::".$component."::Model::".$action))
    : ok(1, "action on model: not applied");
  if ($metrix->{Controller}->{FKout}) {
    ok($metrix->{Controller}->{FKout}->{start}->[0] && $metrix->{Controller}->{FKout}->{end}->[0] && !$metrix->{Controller}->{FKout}->{end}->[1], "generating next key, started and completed") || return($self->red("the last 2 element in FKS in $project"."::$component"."::Filter"));
  }
  ok($metrix->{Controller}->{After}->{start}->[0] && $metrix->{Controller}->{After}->{end}->[0] && !$metrix->{Controller}->{After}->{end}->[1], "\"after\" started and completed") or return($self->red("$project"."::".$component."::Filter::after"));
  if ($metrix->{Controller}->{Email}) {
    ok($metrix->{Controller}->{Email}->{content}->[0], "render email") or return($self->red("template $role/".lc($component)."/$action".".mail.$tag"));
    ok($metrix->{Controller}->{Email}->{start}->[0] && $metrix->{Controller}->{Email}->{end}->[0] && !$metrix->{Controller}->{Email}->{end}->[1], "sending email, started and completed") or return($self->red("email server configuration in $project"."::Config"));
  }
  ok($metrix->{Controller}->{View}->{start}->[0] && $metrix->{Controller}->{View}->{end}->[0] && !$metrix->{Controller}->{View}->{end}->[1], "rendered page with \"$role/".lc($component)."/$action".".$tag\"") or return($self->red("$role/".lc($component)."/$action".".$tag"));
  if ($metrix->{Controller}->{Cache}) {
    ok(!$metrix->{Controller}->{Cache}->{"end"}->[1], "cache ".$metrix->{Controller}->{Name}->{cachecase}->[0]." completed") || return($self->red("cache error: ".$metrix->{Controller}->{Cache}->{"end"}->[1]));
  }
  ok($metrix->{Controller}->{OK}->{responding}->[0], "page delivering") or return($self->red("web server"));

  return;
}

sub blue {
  my $self = shift;
  return $self->color('blue', @_);
}

sub red {
  my $self = shift;
  return $self->color('red', @_);
}

sub color {
  my $self = shift;
  my $color = shift;
  my $str = shift;
  my $module = shift;

  my $str0 = "";
  if ($module) {
    $module =~ s/\:\:/\//g;
    $module .= ".pm" unless (substr($module,-3,3) eq '.pm');
    my $cmd;
    for my $path (@INC) {
      my $try = $path."/".$module;
      if (-e $try) {
        $cmd = "perl -c $try 2>&1";
        last;
      }
    }
    if ($cmd) {
      my @customs;
      for my $path (@INC) {
        push(@customs, $path) unless (grep {$_ eq $path} @lib::ORIG_INC);
      }
      $cmd = "export PERLLIB=".join(':', @customs)."; ".$cmd if (@customs);
      local *M;
      open(M, "$cmd |") || die $!;
      $str0 .= "\n";
      while (<M>) {
        $str0 .= $_;
      }
      close(M); 
    } else {
      $str0 = $module." not found in:\n".join("\n", @INC);
    }
  }
  ($self->{FORMAT} eq 'html') 
	? print "... check ... <strong><span style='color:$color'>$str</span></strong>\n<em>$str0</em>\n"
	: print "... check ... $str\n$str0\n";
}

sub title {
  my $self = shift;
  my $str = shift;

  ($self->{FORMAT} eq 'html') ?  print "<h2>$str</h2>" : print "\n$str\n";

  return;
}

sub s2dhms {
  my $sec = shift;

  return int($sec/(24*60*60)).  " days, ". (($sec/(60*60))%24) . " hours, ". (($sec/60)%60) . " minutes, ". ($sec%60)." seconds";
}

sub report {
  my $self = shift;
  my %hash = @_;
  my $action = $hash{action};
  my $ip = $hash{ip};
  my $ua = $hash{ua};
  return unless ($hash{controller} && $hash{debug});
  my %controller = %{$hash{controller}};

  my $project   = {$controller{script_name}=>$controller{project}};
  my $action_name= $controller{action_name};

  my $logger = Genelet::Logger->new(%{$hash{debug}});
  my ($metrix, $old, $third) = $logger->metrix($ip, $ua, 3);
  my ($p, $q) = split /\?/, $metrix->{URI}, -1;
  unless ($metrix and (substr($p, 0, length($controller{script_name})) eq $controller{script_name})) {
    print "Status: 404 Not Found", "\r\n";
    print "\r\n";
    exit;
  }

  my $screen = 0;
  if ($third && ($third->{Oauth} || $third->{Oauth2}) && !$metrix->{Loginout}->{Out}) {
    $self->title("WHY Report, Screen $screen");
    $screen++;
    $self->log_test($third, $controller{script_name}, $controller{project}, $action_name, $action);
    print "\n";
  }

  if ($old && $old->{METHOD} && ($old->{URL}||$old->{Loginout})) {
    unless ($old->{Controller} || $old->{Loginout}->{Out} || ($old->{Authorize} && $old->{Authorize}->{Static} && !$old->{Authorize}->{Redirect})) {
      $self->title("WHY Report, Screen $screen");
      $screen++;
      $self->log_test($old, $controller{script_name}, $controller{project}, $action_name, $action);
      print "\n";
    }
  }

  $self->title("WHY Report, Screen $screen");
  $self->log_test($metrix, $controller{script_name}, $controller{project}, $action_name, $action);

  if ($self->{MODULES} eq 'no') {
     done_testing();
     return;
  }

  print "\n";
  $self->title("WHY Report, Modules");
  for my $name (qw(Config Model Filter)) {
    my $m = $controller{project}."::$name";
    eval {
      require_ok($m);
      ok($m->new(), $m. "->new();") unless ($name eq 'Config');
    };
    $self->blue($m,$m) if $@;
  }
  if ($self->{MODULES} eq 'full') {
    for (qw(Access::Config Access::DBI)) {
      my $m = $controller{project}."::$_";
      eval {
        require_ok($m);
      };
      $self->blue($m,$m) if $@;
    }
  }

  for (@{$controller{components}}) {
    my $m = $controller{project}."::".$_."::Model";
    my $f = $controller{project}."::".$_."::Filter";
    eval {
      require_ok($m) and ok($m->new(), $m. "->new();");
    };
    $self->blue($m,$m) if $@;
    eval {
      require_ok($f) and ok($f->new(), $f. "->new();");
    };
    $self->blue($f,$m) if $@;
  }

  done_testing();
  return;
}

1;
