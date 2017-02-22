package Genelet::CGIController;

use strict;
use URI::Escape;
use Genelet::CGI;
use Genelet::Controller;
use Genelet::X2h;

use vars qw(@ISA);
@ISA = qw(Genelet::CGI Genelet::X2h Genelet::Controller);

__PACKAGE__->setup_accessors(
  logout => 'logout',
  remotes => [],
  gates   => undef,
  dbis    => undef,
);

sub check404 {
  my $self = shift;

  my $dest = $self->{CACHE}->rewrite(uri_unescape($ENV{REQUEST_URI}))
	if $self->{CACHE};
  $self->{R}->{headers_out}->{"Location"} = $dest || '/';
  return $self->send_status_page(303);
}

sub social {
  my $self = shift;
  my ($role, $tag, $provider) = @_;

  $self->warn("{CGIController}[OK]{start}1");

  my $t = $self->{DBIS}->{$role};
  my $ticket = $t->{$provider} if $t;
  unless ($ticket && ($ticket->role_value() eq $role)) {
    $self->warn("{CGIController}[OK]{fail}1");
    $self->send_status_page(404, "Role Not Found: $role");
    return;
  }
  $self->warn("{CGIController}[In]{start}1");
  $self->warn("{CGIController}[Name]{role}$role");
  my $r = $self->{R};
  $r->param(-name=>$self->{ROLE_NAME}, -value=>$role);
  $r->param(-name=>$self->{PROVIDER_NAME}, -value=>$provider);
  $ticket->r($r);
  my $ret = $ticket->handler();
  $self->warn("{CGIController}[In]{end}1");

  return $ret;
}

sub login {
  my $self = shift;
  my ($role, $tag) = @_;
  my $r = $self->{R};

  $self->warn("{CGIController}[OK]{start}1");

  my $go_uri = $r->param($self->{GO_URI_NAME});
  unless ($go_uri) {
    $go_uri = uri_unescape($ENV{REQUEST_URI});
    $r->param(-name=>$self->{GO_URI_NAME}, -value=>$go_uri);
  }
  if ((!$role || !$tag) && $ENV{SCRIPT_NAME} && $go_uri =~ /^$ENV{SCRIPT_NAME}\/([^\/]+)\/([^\/]+)\//) {
    $role = $1;
    $tag  = $2;
  }
  unless ($role) {
    $self->send_status_page(404, "Role Not Found for Login");
    return;
  }

  $r->param(-name=>$self->{ROLE_NAME}, -value=>$role);
  $r->param(-name=>$self->{TAG_NAME}, -value=>$tag);

  my $t = $self->{DBIS}->{$role};
  unless ($t) {
    $self->warn("{CGIController}[OK]{fail}1");
    $self->send_status_page(404, "Role Not Found");
    return;
  }
  my $provider = $r->param($self->{PROVIDER_NAME});
  $self->warn("{CGIController}[Name]{provider}$provider");
  unless ($provider) {
    while (my ($k, $v) = each %$t) {
      $provider = $k;
      if ($v->default()) {
        last;
      }
    }
  }  
  #my $ticket = $t->{$provider} || $t->{"db"} || $t->{"plain"};
  my $ticket = $t->{$provider};
  unless ($ticket) {
    $self->warn("{CGIController}[OK]{fail}1");
    $self->send_status_page(404, "Ticket Case Not Found");
    return;
  }
  $self->warn("{CGIController}[In]{start}1");
  $self->warn("{CGIController}[Name]{role}$role");
  $ticket->r($r);
  $ticket->handler();
  $self->warn("{CGIController}[In]{end}1");
 
  return;
}

sub run {
  my $self = shift;
  my $r = $self->{R};

  my $logger = $self->{LOGGER};
  $logger->screen_start($ENV{REQUEST_METHOD}, ($ENV{REDIRECT_REQUEST_URI} && $ENV{REDIRECT_REQUEST_URI} eq $ENV{REQUEST_URI}) ? $ENV{SCRIPT_NAME}.$ENV{PATH_INFO}."?".$ENV{QUERY_STRING} : $ENV{REQUEST_URI}, $ENV{REMOTE_ADDR}, $ENV{HTTP_USER_AGENT}) if ($logger && $logger->is_warn() && $logger->can('screen_start'));
  if ($logger && $logger->is_debug()) {
    while (my ($k, $v) = each %ENV) {
      $logger->debug($k. "=>". $v);
    }
  }

  if ($ENV{REQUEST_METHOD} eq 'POST' and $r->param('POSTDATA') and $ENV{CONTENT_TYPE} =~ /(text|application)\/(json|xml)/i) {
    my $hash = {};
    if ($ENV{CONTENT_TYPE} =~ /json/i) {
      my $json = JSON->new->allow_nonref->allow_unknown->allow_blessed->utf8;
      $hash = $json->decode($r->param('POSTDATA'));
    } else {
      my $p = $self->{STORAGE}->{xmlparser} if $self->{STORAGE};
      $p ||= XML::LibXML->new();
      my $doc = $p->parse_string($r->param('POSTDATA'));
      $hash = $self->x2h($doc) if $doc;
    }
    if (ref($hash) eq 'HASH') {
      while (my ($k, $v) = each %$hash) {
        $logger->debug($k. "=>". $v) if $logger;
        $r->param(-name=>$k, -value=>$v);
      }
    } elsif (ref($hash) eq 'ARRAY') {
      $logger->debug($hash) if $logger;
      $r->param(-name=>'_garray', -value=>$hash);
    }
    $r->delete('POSTDATA');
  }

  if ($ENV{REQUEST_METHOD} eq 'OPTIONS' and $ENV{HTTP_ORIGIN}) {
    $r->{headers_out}->{"Access-Control-Allow-Origin"} = $ENV{HTTP_ORIGIN};
    $r->{headers_out}->{"Access-Control-Allow-Headers"} = 'x-requested-with';
    $r->{headers_out}->{"Access-Control-Allow-Methods"} = 'GET, POST';
    $r->{headers_out}->{"Access-Control-Allow-Credentials"} = 'true';
    return $self->send_status_page(200);
  }

  my $method_found = 0;
  for my $k (keys %{$self->{DEFAULT_ACTIONS}}) {
    if ($ENV{REQUEST_METHOD} eq $k) {
      $method_found = 1;
      last;
    }
  }
  if (!$method_found) {
    $self->send_status_page(404, "Wrong Request Method");
    return;
  }

  return $self->check404() if ($ENV{REDIRECT_STATUS} && $ENV{REDIRECT_STATUS} eq '404');
  unless ($ENV{PATH_INFO}) {
    $self->send_status_page(404, "Wrong URL");
    return;
  }

  (undef, my @path_info) = split /\//, $ENV{PATH_INFO}, -1;
  if (@path_info==4 and $ENV{REQUEST_METHOD} eq "GET") {
    $r->param(-name=>"_gid_url", -value=>$path_info[3]);
  } elsif (@path_info!=3) {
    $self->send_status_page(404, "Wrong URL");
  }

  my $role = $path_info[0];
  my $tag  = $path_info[1]; # could be tag, provider--oauth, or logout
  my $obj  = $path_info[2];

  return $self->login($role, $tag) if ($obj eq $self->{LOGIN_NAME});
  return $self->social($role, $tag, $obj) if (grep {$obj eq $_} @{$self->{REMOTES}});

  my $gate = $self->{GATES}->{$role};
  $gate->r($r) if $gate;

  if ($obj eq $self->{LOGOUT_NAME}) {
    $self->warn("{CGIController}[OK]{start}1");
    $self->warn("{CGIController}[Out]{start}1");
    $self->warn("{CGIController}[Name]{role}".$role);
    return $gate->handler_logout($role, $tag);
    $self->warn("{CGIController}[Out]{end}1");
  }

  if ($gate || ($self->{SHADOWS} && $self->{SHADOWS}->{$role})) {
    $self->warn("{CGIController}[Program]{start}1");
    $self->warn("{CGIController}[Name]{role}".$role);
    my $status = ($self->{SHADOWS}->{$role}) ? $gate->verify_oauth($self->{CODINGS}, $self->{SECRETS}) : $gate->verify_cookie();
    $self->warn("{CGIController}[Name]{status}".$status);
    if ($status && ($status < 1000)) {
      $self->send_status_page($status);
      return;
    } elsif ($status) {
      my $chartags = $gate->chartags();
      my $chartag = $chartags->{$tag} if $chartags;
      if ($chartag && $chartag->{Case}>0) {
        $r->{headers_out}->{"Content-Type"} = $chartag->{"Content-Type"};
        if ($chartag->{Short} eq 'jsonp') {
          my $cb = $r->param($self->{CALLBACK_NAME}) || $self->{CALLBACK_NAME};
          return $self->send_nocache($cb.'("data":"'.$chartag->{challenge}.'"})');
        } else {
          $r->{headers_out}->{"Access-Control-Allow-Origin"} = $ENV{HTTP_ORIGIN} || '*';
          $r->{headers_out}->{"Access-Control-Allow-Credentials"} = 'true';
          $self->warn("{CGIController}[Name]{API}".'{"data":"'.$chartag->{challenge}.'"}');
          return $self->send_nocache('{"data":"'.$chartag->{challenge}.'"}');
        }
      } else {
        return $gate->forbid($status, $role, $tag, $obj);
      }
    }
    #$ENV{REMOTE_USER} = $gate->auth()->{'X-Forwarded-User'};
    $self->warn("{CGIController}[Program]{end}1");
    $self->warn("{CGIController}[Name]{user}".$ENV{REMOTE_USER});
  }

  return $self->handler($ENV{PATH_INFO}, $gate);
}

1;
