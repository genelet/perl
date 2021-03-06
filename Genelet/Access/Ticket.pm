package Genelet::Access::Ticket;

use strict;

#use URI;
use Genelet::Access;
use vars qw(@ISA $VERSION);

use Data::Dumper;
$Data::Dumper::Terse = 1;

$VERSION = 1.01;
@ISA = ('Genelet::Access');

__PACKAGE__->setup_accessors(
  cookietype => 'cookie',
  credential => [],
  condition_uri => undef,

  found      => undef,

  def_pagename  => "login",
  def_extention => "html",
  def_login     => "hello",
  def_password  => "world",
  default       => 0,

  attributes  => undef,
  out_pars    => undef,
  out_hash    => {},

  provider    => "",
);

sub handler {
  my $self = shift;
  my $r = $self->{R};

  $self->{FOUND} = $self->get_cookie($self->{GO_PROBE_NAME}) if ($self->{COOKIETYPE} eq 'auto' || $self->{COOKIETYPE} eq 'cookie');

  my $uri = $r->param($self->{GO_URI_NAME}) || $self->{FOUND};
  return $self->send_status_page(404, "Destination Not Found") unless $uri;

  if ($self->{CREDENTIAL}->[2] && $r->param($self->{CREDENTIAL}->[2])) {
    $self->warn("{Loginout}[Case]{direct}1");
    return $self->handler_login($uri);
  }

  if (($self->{COOKIETYPE} eq 'cookie') && !$self->{FOUND}) {
    $self->warn("{Loginout}[Case]{probe}1:1036");
    $self->set_cookie($self->{GO_PROBE_NAME}, $uri);
    return $self->send_nocache($self->loginpage(1036, $uri, $r));
  } elsif ($self->{COOKIETYPE} eq 'cookie') {
    $self->warn("{Loginout}[Case]{probe}1");
  }

  if (my $err = $r->param($self->{GO_ERR_NAME})) {
    $self->warn("{Loginout}[Case]{code}$err");
    $self->set_cookie($self->{GO_PROBE_NAME}, $uri);
    return $self->send_nocache($self->loginpage($err, $uri));
  }

  return $self->handler_login($uri);
}

sub handler_login {
  my $self = shift;
  my $uri = shift;
  my $r = $self->{R};

  $self->warn("{Loginout}[Authenticate]{start}1");

  $uri ||= $r->param($self->{GO_URI_NAME}) || $self->get_cookie($self->{GO_PROBE_NAME});

  if ($self->{CREDENTIAL}->[3] && ($self->{CREDENTIAL}->[3] eq $self->{SURFACE}) && $r->param($self->{SURFACE})) {
    $self->warn("{Loginout}[Authenticate]{blind}1");
    my $err = $self->verify_cookie($r->param($self->{SURFACE}));
    $self->warn("{Loginout}[Authenticate]{end}1:$err");
    if ($err) {
      return $self->send_nocache($self->loginpage($err, $uri));
    } else {
      $self->set_cookie($self->{SURFACE}."_", $r->param($self->{SURFACE}));
      $self->set_cookie($self->{SURFACE}, $r->param($self->{SURFACE}), $self->{MAX_AGE}) if $self->{MAX_AGE};
      $r->{headers_out}->{"Location"} = $uri;
      return $self->send_status_page(303);
    }
  }

  my $login    = $r->param($self->{CREDENTIAL}->[0]);
  my $password = $r->param($self->{CREDENTIAL}->[1]);
  if ($login) { 
    $login =~ s/^\s+//g;
    $login =~ s/\s+$//g;
    $self->warn("{Loginout}[Name]{login}".$login);
  }
  if ($password) {
    $password =~ s/^\s+//g;
    $password =~ s/\s+$//g;
  }
  #my $err = $self->authenticate($login, $password, $uri);
  my $err = $self->authenticate($login, $password);
  $self->warn("{Loginout}[Authenticate]{end}1:$err");
  if ($err && ($err < 1000)) {
    return $self->send_status_page($err);
  } elsif ($err) {
    return $self->send_nocache($self->loginpage($err, $uri));
  }
 
  return $self->handler_fields($uri);
}

sub handler_fields {
  my $self = shift;
  my ($uri) = @_;
  my $r = $self->{R};

  my $fields = $self->get_fields();

  # ["tA10","o_found","A","/v1/public/e/apply?action=startlin&status=New","registerID","m_email","m_firstname","m_lastname"],
  # ["uC01","/v1/school/e/","_md5","/v1/school/e/school?action=topics"]
  # how, variable name, value, base uri, others wholse values in redirect
  # how: (t, u, p)+(A, B, C)+(0,1)+(0,1), t:out_hash, u:go_uri, p:provider
  # for u and p, go_uri has to match values[1]
  # A:equal, B:not equal, C:match,
  # 0: no stamp nor md5, 1: stamp and md5; 0:no coookie, 1:cookie

  if ($self->{CONDITION_URI}) {
    my $outs = $self->{OUT_HASH};
    foreach my $values (@{$self->{CONDITION_URI}}) {
      my @how = split '', $values->[0], -1;
      my $obs = "";
      if ($how[0] eq "t") {
        $obs = $outs->{$values->[1]};
      } else {
        if ($how[0] eq "p") {
          $obs = $self->{PROVIDER};
        } else {
          $obs = $uri;
        }
        my $newuri = URI->new($uri);
        next unless (substr($newuri->path(), 0, length($values->[1])) eq $values->[1]);
      }
      if (($how[1] eq "A" && $obs eq $values->[2]) or
          ($how[1] eq "B" && $obs ne $values->[2]) or
          ($how[1] eq "C" && $obs =~ /$values->[2]/)) {
        my $target = URI->new($values->[3]);
        my $q = $target->query();
        for (my $i=4; $i<length(@$values); $i++) {
          my $par = $values->[$i];
          $q->{$par} = $outs->{$par} if defined($outs->{$par});
        }
        #if ($how[2] eq "1") {
        #  $q->{c.Go_stamp_name,fmt.Sprintf("%d", Unix_timestamp()))
        #  $q->{c.Go_md5_name, SortMapMd5(c.Secret, self.C.Go_md5_name, q))
        #}
        $target->query($q);
        $uri = $target->as_string();
        if ($how[3] eq "0") {
          $r->{headers_out}->{"Location"} = $uri;
          return $self->send_status_page(303);
        }
      }
    }
  }

  my $signed = $self->signature($fields);
  $self->set_cookie($self->{SURFACE}."_", $signed);
  $self->set_cookie($self->{SURFACE}, $signed, $self->{MAX_AGE}) if $self->{MAX_AGE};

  my $tag = $r->param($self->{TAG_NAME}) if $self->{TAG_NAME};
  my $chartag = $self->{CHARTAGS}->{$tag} if ($self->{CHARTAGS} && $tag);
  if ($chartag && $chartag->{Case}>0) {
    $r->{headers_out}->{"Content-Type"} = $chartag->{"Content-Type"};
    if ($chartag->{Short} eq 'jsonp') {
      my $callback = $r->param($self->{CALLBACK_NAME}) || $self->{CALLBACK_NAME};
      return $self->send_nocache($callback.'({"data":"'.$chartag->{Logged}.'"})');
    } else {
      $self->{R}->{headers_out}->{"Access-Control-Allow-Origin"} = $ENV{HTTP_ORIGIN} || '*';
      $self->{R}->{headers_out}->{"Access-Control-Allow-Credentials"} = 'true';
      return $self->send_nocache('{"data":"'.$chartag->{Logged}.'"}');
    }
  }

  #if (($self->{COOKIETYPE} eq 'cookie') || $self->{FOUND} || $r->param($self->{CREDENTIAL}->[2])) { #browser ok cookie or force cookie
  #  $self->warn("{Loginout}[Signature]{cookie}1");
  #} else {
  #  $self->warn("{Loginout}[Signature]{url}1");
  #  my $newuri = URI->new($uri);
  #  $newuri->path("/".$self->{SURFACE}."/".$signed . $newuri->path);
  #  $uri = $newuri->as_string();
  #}

  $self->warn("{Loginout}[Signature]{redirect}".$uri);
  $r->{headers_out}->{"Location"} = $uri;
  return $self->send_status_page(303);
}

sub authenticate {
  my $self = shift;
  my ($login, $password, $uri) = @_;

  return 1037 unless ($login && $password);
  return 1031 unless ($login eq $self->{DEF_LOGIN} && $password eq $self->{DEF_PASSWORD});

  $self->{OUT_PARS} = ['login'];
  $self->{OUT_HASH} = {login=>$login};

  return;
}

sub loginpage {
  my $self = shift;
  my ($err, $go_uri) = @_;
  my $r = $self->{R};

  my $tag = $r->param($self->{TAG_NAME}) if ($r && $self->{TAG_NAME});
  my $chartag = $self->{CHARTAGS}->{$tag} if ($self->{CHARTAGS} && $tag);
  if ($chartag && $chartag->{Case}>0) {
    $r->{headers_out}->{"Content-Type"} = $chartag->{"Content-Type"};
    if ($chartag->{Short} eq 'jsonp') {
      my $callback = $r->param($self->{CALLBACK_NAME}) || $self->{CALLBACK_NAME};
      return $callback.'({"data":"'.$chartag->{Failed}.'"})';
    } else {
      $r->{headers_out}->{"Access-Control-Allow-Origin"} = $ENV{HTTP_ORIGIN} || '*';
      $r->{headers_out}->{"Access-Control-Allow-Credentials"} = 'true';
      return '{"data":"'.$chartag->{Failed}.'"}';
    }
  }

  return $self->template_page($err, $go_uri)
	|| $self->plain_page($err, $go_uri);
}

sub template_page {
  my $self = shift;
  my ($err, $go_uri) = @_;
  my $r = $self->{R};

  my ($role, $ext);

  my $rest = $go_uri;
  my $ext;
  my $len = length($self->{SCRIPT});
  if (substr($rest, 0, $len) eq $self->{SCRIPT}) {
    substr($rest, 0, length($self->{SCRIPT})) = '';
    my @a = split /\//, $rest;
    for (@a) {
      return if (/^\./);
    }
    $role = $a[1];
    $ext  = $a[2];
  } elsif ($r) {
    $role = $r->param($self->{ROLE_NAME}) if $self->{ROLE_NAME};
    $ext  = $r->param($self->{TAG_NAME}) if $self->{TAG_NAME};
  }
  return unless $role;
  $ext ||= $self->{DEF_EXTENTION};

  my $output = '';
  my $e = $self->get_loginpage(
	\$output,
	{
	error       =>$err,
	errorstr    =>$self->error_str($err),
	script      =>$self->{SCRIPT},
	Login_name  =>$self->{LOGIN_NAME},
	go_uri      =>$go_uri,
	role        =>$role,
	go_uri_name =>$self->{GO_URI_NAME},
	role_name   =>$self->{ROLE_NAME},
	Login       =>$self->{CREDENTIAL}->[0],
	Password    =>$self->{CREDENTIAL}->[1]
	},
	$self->{TEMPLATE}."/".$role."/:".$self->{TEMPLATE}."/common/",
	$self->{DEF_PAGENAME}.".".$ext
  );

  if ($e) {
    $self->{LOGGER}->warn(Dumper($e)) if $self->{LOGGER};
    return;
  }
  
  return $output;
}

sub plain_page {
  my $self = shift;
  my ($err, $go_uri, $role) = @_;

  my $str = $self->error_str($err);
  $str = qq~<html>
<head>
<title>Sign In</title>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<META HTTP-EQUIV="Expires" CONTENT="Mon, 01 Jan 1990 20:52:26 GMT">
</head>
<body style="font-family: Arial, Helvetica, sans-serif">
<h2>Sign In</h2>
<h4><a href="/">Back to Home</a></h4>
<em>$str</em>
~;
  if ($go_uri) {
    my $c0 = $self->{GO_URI_NAME};
    my $c1 = $self->{CREDENTIAL}->[0];
    my $c2 = $self->{CREDENTIAL}->[1];
    $str .= qq~ <FORM METHOD="POST"><INPUT TYPE="HIDDEN" NAME="$c0" VALUE="$go_uri">
<pre>
   Login: <INPUT style="margin:2px; padding:2px" TYPE="TEXT"  NAME="$c1" />
Password: <INPUT style="margin:2px; padding:2px" TYPE="PASSWORD" NAME="$c2" />

          <button TYPE="SUBMIT"> Sign In </button>
</pre>
</FORM>
~;
  }

  return $str . qq~</body></html>
~;
}

sub get_fields {
  my $self = shift;
  my $hash = shift;
  my $outs = $self->{OUT_HASH};

  my $fields = [];
  my $i=0;
  for my $par (@{$self->{ATTRIBUTES}}) {
    $fields->[$i] = $self->{uc $par};
    $fields->[$i] = $hash->{$par} if(!defined($fields->[$i]) && $hash);
    $fields->[$i] = $outs->{$par} if(!defined($fields->[$i]) && $outs);
    $i++;
  }

  return $fields;
}

1;
