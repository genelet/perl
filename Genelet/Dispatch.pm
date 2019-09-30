#package Gate;
#use Genelet::CGI;
#use Genelet::Access;
#our @ISA = qw(Genelet::CGI Genelet::Access);
#
package Anonymous;
use Genelet::CGI;
use Genelet::Access::Anonymous;
our @ISA = qw(Genelet::CGI Genelet::Access::Anonymous);


package Genelet::Dispatch;

use Data::Dumper;
use strict;
use utf8;
use JSON;
use URI::Escape;
use Encode qw(decode encode);

#use DBI;
#use File::Find;
#use Data::Dumper;
#use URI;
#use URI::Escape();
#use Digest::HMAC_SHA1;
#use MIME::Base64();
#use Net::SMTP;
#use Template;

#use GTop ();

use Genelet::Access::Gate;
use Genelet::CGIController;
use Genelet::Cache;
use Genelet::Logger;
use Genelet::Access::Gate;
use Genelet::Access::Ticket;

use vars qw(%CONTROLLER %DEBUG %ERRORS %ROUTES %ACCESSES);

sub init {
  my $config = shift;
  my $Libpath = shift;
  my $Components = shift;
  my $Fcgi = shift;
  my $Post_max = shift || 1024*1024*3;
  my $Storage = shift;

  my $cgi = ($Fcgi) ? "CGI::Fast" : "CGI";
  eval "use $cgi qw(:cgi)";
  die $@ if $@;
  $CGI::POST_MAX = $Post_max;

  my $PROJECT = $config->{Project} or die "project name must be defined";

  unless ($Libpath) {
    my @parts = split /\//, $config->{Document_root}, -1;
    my $real = pop @parts;
    pop(@parts) unless $real;
    push @parts, "lib";
    $Libpath = join(/\//, @parts);
  }
  unless ($Components) {
    $Components = [];
    opendir(DIR, $Libpath) || die "When open $Libpath: $!";
    for (grep {/^[A-Z]/} readir(<DIR>)) {
      push @$Components, $_;
    }
    close(DIR);
  }
  $Storage = {} unless $Storage;
  $Storage->{_CONFIG} = $config;
  for my $c (@$Components) {
    my $json = $Libpath . "/" . $PROJECT . "/" . $c . "/component.json";  
    die "$json of $c not found!" unless (-e $json);
    local $/;
    open(my $fh, '<', $json) or die "When open $json $!";
    my $json_text = <$fh>;
    close($fh);
    #my $component = decode_json( $json_text );
    my $component = JSON->new->utf8(0)->decode( $json_text );
    die "Incorrect json configuration for $json." unless $component;
    $Storage->{$c} = $component;
  } 

  my $error = "";
  for my $mf (qw(Model Filter)) {
    my $m = $PROJECT."::$mf";
    eval "require $m";
    $error .= $@ if ($@);
    for (@{$Components}) {
      my $f = $PROJECT."::".$_."::$mf";
      eval "require $f";
      $error .= $@ if ($@);
    }
  }
  my $logger = Genelet::Logger->new(%{$config->{Log}}) if $config->{Log};
  $logger->emergency($error) if ($logger && $error);

  my %base = (env=>\%ENV, storage=>$Storage);
  for my $key (keys %$config) {
    next if ($key eq "Roles");
    $base{lc $key} = $config->{$key}
  }
  $base{logger} = $logger if $logger;
  
  my $gates;
  my $dbis;
  my $remotes;
  my $roles;
  while (my ($role, $item) = each %{$config->{Roles}}) {
    for (qw(Id_name Is_admin Attributes Type_id)) {
      $roles->{$role}->{lc $_} = $item->{$_} if $item->{$_};
    }
    my %pars;
    for (qw(Coding Secret Surface Length Duration Userlist Grouplist
Logout Domain Path Max_age)) {
      $pars{lc $_} = $item->{$_} if $item->{$_};
    }
    $pars{role_value} = $role;
    $gates->{$role} = Genelet::Access::Gate->new(%base, %pars);
    for my $provider (keys %{$item->{Issuers}}) {
      my $issuer = $item->{Issuers}->{$provider};
      my %last;
      $last{attributes} = $item->{Attributes};
      $last{provider} = $provider;
      for (qw(Default Screen Sql Sql_as Credential In_pars Out_pars)) {
        $last{lc $_} = $issuer->{$_} if $issuer->{$_}; 
      }
      push @$remotes, $provider if ($provider ne 'db' and $provider ne "plain");
      if ($issuer->{Provider_pars}) {
        while (my ($k, $v) = each %{$issuer->{Provider_pars}}) {
          $last{lc $k} = $v;
		}
	  }
      my $m = "Genelet::CGIAccess::".ucfirst($provider);
      eval "require $m";
      $error .= $@ if ($@);
      $dbis->{$role}->{$provider} = $m->new(%base, %pars, %last);
    }
  }

  my $c = Genelet::CGIController->new(
	%base,
	remotes => $remotes,
	roles   => $roles,
	dbis    => $dbis,
	gates   => $gates);


  my $cache = Genelet::Cache->new(
    routes        => $config->{Static},
    document_root => $config->{cache_root}||$config->{document_root},
    script        => $config->{script},
    action_name   => $config->{action_name}
  ) if $config->{Static};
  $c->cache($cache) if $cache;

  return ($cgi, $c);
}

sub run {
  my $config = shift;
  $config = get_hash($config) unless (ref($config) eq 'HASH');
  my ($cgi, $c) = init($config, @_);

  unless ($_[3]) {
    $c->r($cgi->new());
    return $c->run();
  }

  while (my $r = $cgi->new()) {
    $c->r($r);
    $c->run();
  }

  return;
}

sub get_hash {
  my $config = shift;

  local $/;
  open( my $fh, '<', $config) or die $!;
  my $json_text = <$fh>;
  close($fh);
  #my $c = decode_json( $json_text );
  my $c = JSON->new->utf8(0)->decode( $json_text );
  die "No configuration." unless $c;

  return $c;
}

sub run_test {
  my ($request, $ip, $config, $lib, $comps) = @_;

  $config = get_hash($config) unless (ref($config) eq 'HASH');
  my ($cgi, $c) = init($config, $lib, $comps);

  open my $saved_stdout, ">&STDOUT" or die "Can't dup STDOUT: $!";
  close STDOUT;
  my $output = "";
  open STDOUT, '>', \$output or die $!;

  my $uri = $request->uri();

  my $pathinfo = $uri->path();
  my $n = length($config->{Script});
  die "Wrong path info" unless ($config->{Script} eq substr($pathinfo, 0, $n));
  $pathinfo = substr($pathinfo, $n, length($pathinfo)-$n);
  %ENV = (
  'DOCUMENT_ROOT' => $config->{Document_root},
  'REQUEST_METHOD' => $request->method(),
  'REQUEST_URI' => $uri->path_query(),
  'HTTP_HOST' => $uri->host(),
  'PATH_INFO' => $pathinfo,
  'REMOTE_ADDR' => $ip,
  'SCRIPT_NAME' => $config->{Script},
  'QUERY_STRING' => $uri->query(),
  'HTTP_COOKIE' => $request->header("Cookie")
  );

  my $r = $cgi->new($ENV{QUERY_STRING});
  if ($ENV{REQUEST_METHOD} eq "POST") {
    my $body = decode('UTF-8', $request->content());
    if ($request->header("Content-Type") eq "application/x-www-form-urlencoded") {
	  my @items = split('&', $body, -1);
      for my $item (@items) {
        my @two = split('=', $item, 2);
        my $v = uri_unescape($two[1]); $v =~ s/\+/ /g;
        $r->append(-name=>$two[0], -values=>$v);
      }
    } else {
      $r->param('POSTDATA') = $body;
    }
  }

  $c->r($r);
  $c->run();

  close STDOUT;
  open STDOUT, ">&", $saved_stdout or die "Can't dup $saved_stdout: $!";

  return $output;
}

1;
