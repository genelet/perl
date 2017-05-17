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
use JSON;
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
  for my $c (@$Components) {
    my $json = $Libpath . "/" . $PROJECT . "/" . $c . "/component.json";  
    die "$json of $c not found!" unless (-e $json);
    local $/;
    open(my $fh, '<', $json) or die "When open $json $!";
    my $json_text = <$fh>;
    close($fh);
    my $component = decode_json( $json_text );
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
    while (my ($provider, $issuer) = each %{$item->{Issuers}}) {
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
    script_name   => $config->{script_name},
    action_name   => $config->{action_name}
  ) if $config->{Static};
  $c->cache($cache) if $cache;

  return ($cgi, $c);
}

sub run {
  my $config = shift;
  unless (ref($config) eq 'HASH') {
    local $/;
    open( my $fh, '<', $config) or die $!;
    my $json_text = <$fh>;
    close($fh);
    $config = decode_json( $json_text );
    die "No configuration." unless $config;
  }

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

sub run_test {
  my $config = shift;
  unless (ref($config) eq 'HASH') {
    local $/;
    open( my $fh, '<', $config) or die $!;
    my $json_text = <$fh>;
    close($fh);
    $config = decode_json( $json_text );
    die "No configuration." unless $config;
  }

  my ($cgi, $c) = init($config, @_);

  open my $saved_stdout, ">&STDOUT" or die "Can't dup STDOUT: $!";
  close STDOUT;
  my $output = "";
  open STDOUT, '>', \$output or die $!;

  my $r = CGI->new($ENV{QUERY_STRING});
  $c->r($r);
  $c->run();

  close STDOUT;
  open STDOUT, ">&", $saved_stdout or die "Can't dup $saved_stdout: $!";

  return $output;
}

1;
