package Genelet::CGI;

use strict;
use URI::Escape;

sub send_status_authorizer {
  my $self = shift;
  my $status = shift;

  my $headers = $self->{R}->{headers_out};

  print "Status: $status\r\n";
  foreach my $key (keys %$headers) {
    my $value = $headers->{$key};
    if (ref($value) eq 'ARRAY') {
      print "$key: $_\r\n" for @$value;
    } else {
      print "$key: $value\r\n";
    }
  }
  print "\r\n";

  return;
}

sub _send_status_page {
  my $self = shift;
  my ($status, $content) = @_;

  my %HTTP_STATUS = (
    200 => "OK",
    301 => "Moved Permanently",
    302 => "Found",
    303 => "See Other",
    304 => "Not Modified",
    400 => "Bad Request",
    401 => "Unauthorized",
    402 => "Payment Required",
    403 => "Forbidden",
    404 => "Not Found",
    405 => "Method Not Allowed",
    500 => "Internal Server Error",
  );

  my $headers = $self->{R}->{headers_out};
  $headers->{"Content-Type"} ||= "text/html; charset=UTF-8";

  print "Status: $status ", $HTTP_STATUS{$status}, "\r\n";
  if ($status == 303 and ($ENV{HTTP_AUTHORIZATION} && $ENV{HTTP_AUTHORIZATION} =~ /^\s*OAuth\s(.*)$/i)) {
    print "Authorization: " . $ENV{HTTP_AUTHORIZATION} . "\r\n";
  }

  foreach my $key (keys %$headers) {
    my $value = $headers->{$key};
    if (ref($value) eq 'ARRAY') {
      print "$key: $_\r\n" for @$value;
    } else {
      print "$key: $value\r\n";
    }
  }
  print "\r\n";

  if ($status >= 400) {
    $content ||= '';
    print "Status: $status ", $HTTP_STATUS{$status}, "; $content";
  } elsif ($status == 200) {
    print $content;
  }

  return;
}


sub send_status_page {
  my $self = shift;
  my ($status, $content) = @_;

  my %HTTP_STATUS = (
    200 => "OK",
    301 => "Moved Permanently",
    302 => "Found",
    303 => "See Other",
    304 => "Not Modified",
    400 => "Bad Request",
    401 => "Unauthorized",
    402 => "Payment Required",
    403 => "Forbidden",
    404 => "Not Found",
    405 => "Method Not Allowed",
    500 => "Internal Server Error",
  );

  my $headers = $self->{R}->{headers_out};
  $headers->{"Content-Type"} ||= "text/html; charset=UTF-8";

  my $str = "Status: $status ". $HTTP_STATUS{$status}. "\r\n";
  if ($status == 303 and ($ENV{HTTP_AUTHORIZATION} && $ENV{HTTP_AUTHORIZATION} =~ /^\s*OAuth\s(.*)$/i)) {
    $str .= "Authorization: " . $ENV{HTTP_AUTHORIZATION} . "\r\n";
  }

  foreach my $key (keys %$headers) {
    my $value = $headers->{$key};
    if (ref($value) eq 'ARRAY') {
      $str .= "$key: $_\r\n" for @$value;
    } else {
      $str .= "$key: $value\r\n";
    }
  }
  $str .= "\r\n";

  if ($status >= 400) {
    $content ||= '';
    $str .= "Status: $status ". $HTTP_STATUS{$status}. "; $content";
  } elsif ($status == 200) {
    $str .= $content;
  }

  print $str;
  return;
}


sub forbid {
  my $self = shift;
  my ($error, $role, $tag, $obj) = @_;

  my $escaped = ($ENV{SCRIPT_NAME}.$ENV{PATH_INFO}) || $ENV{REQUEST_URI};
  $escaped .= "?". $ENV{QUERY_STRING} if $ENV{QUERY_STRING};
  $escaped = uri_escape($escaped);
  $self->set_cookie($self->{GO_PROBE_NAME}, $escaped);
  $self->set_cookie_expired($self->{SURFACE});
  my $redirect = $self->{REDIRECT}||$ENV{SCRIPT_NAME}||$self->{SCRIPT};
  
  $redirect .= "/$role/$tag/" . $self->{LOGIN_NAME} . "?" . $self->{GO_URI_NAME} . "=$escaped&" . $self->{GO_ERR_NAME} . "=$error";
  $self->{R}->{headers_out}->{"Location"} = $redirect;
  $self->warn("{CGI}[Name]{Redirect}".$redirect);
  return $self->send_status_page(303);
};

sub send_nocache {
  my $self = shift;
  my ($output) = @_;

  $self->{R}->{headers_out}->{"Pragma"} = "no-cache";
  $self->{R}->{headers_out}->{"Cache-Control"} = "no-cache, no-store, max-age=0, must-revalidate";

  return $self->send_status_page(200, $output);
}

sub send_page {
  my $self = shift;
  my ($output, $cachepage, @stats) = @_;

  my @MONTH = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my @WEEK  = qw(Sun Mon Tue Wed Thu Fri Sat);

  my $status = 200;
  if ($cachepage) {
    my ($ino, $size, $mtime) = (@stats)
		? @stats[1,7,9] : (stat($cachepage))[1,7,9];
    my $etag = sprintf("%x-%x-%x", $ino, $size, $mtime);
    my @z = gmtime($mtime);
    my $lmt = sprintf("%s, %02d %s %02d %02d:%02d:%02d GMT", $WEEK[$z[6]], $z[3], $MONTH[$z[4]], 1900+$z[5], $z[2], $z[1], $z[0]);
    if ($ENV{HTTP_IF_MODIFIED_SINCE} && $ENV{HTTP_IF_MODIFIED_SINCE} eq $lmt && $ENV{HTTP_IF_NONE_MATCH} && $ENV{HTTP_IF_NONE_MATCH} eq '"'.$etag.'"') {
      $status = 304;
    }
    my $headers_out = $self->{R}->{headers_out};
    $headers_out->{"Etag"} = '"'. $etag.'"';
    $headers_out->{"Accept-Ranges"} = "bytes";
    $headers_out->{"Content-Length"} = $size;
    $headers_out->{"Last-Modified"} = $lmt;
# if Expires, then delete or update will not force browser to refresh -- it
# uses the old page in browser, not asks for server unless click refresh button
    if (scalar(@stats)==14) {
      @z = gmtime($mtime + pop(@stats));
      $headers_out->{"Expires"} = sprintf("%s, %02d %s %02d %02d:%02d:%02d GMT", $WEEK[$z[6]], $z[3], $MONTH[$z[4]], 1900+$z[5], $z[2], $z[1], $z[0]), "\r\n";
    }
  }

  return $self->send_status_page($status, $output);
}

sub get_origin {
  my $self = shift;

  return $ENV{HTTP_ORIGIN} || '*';
}

sub get_scriptfull {
  my $self = shift;

  return $self->get_proto()."://".$self->get_servername().$self->get_scriptname();
}

sub get_query_string {
  my $self = shift;

  return $ENV{QUERY_STRING};
}

sub get_json_url {
  my $self = shift;

  my @a = split '/', $ENV{PATH_INFO}, -1;
  $a[2] = 'json';

  return $self->get_scriptfull().join('/',@a).($self->get_query_string() ? '?'.$self->get_query_string() : '');
}

sub build_uri {
  my $self = shift;

  return $self->get_scriptfull().$ENV{PATH_INFO}.($self->get_query_string() ? '?'.$self->get_query_string() : '');
}

sub get_scriptname {
  my $self = shift;

  return $self->{SCRIPT} || $ENV{SCRIPT_NAME};
}

sub get_documentroot {
  my $self = shift;

  return $self->{DOCUMENT_ROOT} || $ENV{DOCUMENT_ROOT};
}

sub get_servername {
  my $self = shift;

  return $ENV{HTTP_HOST} || $ENV{SERVER_NAME};
}

sub get_proto {
  my $self = shift;

  return $ENV{HTTP_X_FORWARDED_PROTO} if $ENV{HTTP_X_FORWARDED_PROTO};
  return ($ENV{HTTPS}) ? "https" : "http";
}

sub get_cookie {
  my $self = shift;
  my $name = shift;

  my $raw_cookie = $ENV{HTTP_COOKIE} or return;
  my $val;
  foreach (split("; ?", $raw_cookie)) {
    s/\s*(.*?)\s*/$1/;
    my ($key0, $val0) = split /=/, $_, 2;
    $val = $val0 if ($key0 eq $name."_" or $key0 eq $name);
  }

  return $val;
}

my $expires = sub {
  my $t = shift;

  my @weeks  = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
  my @months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
				"Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
   
  my ($sec, $min, $hour, $d, $m, $y, $w) = gmtime($t);
  return sprintf("%.3s, %02d-%.3s-%04d %02d:%02d:%02d GMT",
				$weeks[$w], $d, $months[$m], $y+1900, $hour, $min, $sec);
};

sub set_cookie {
  my $self = shift;

  my ($name, $value, $max_age, $domain, $path) = @_;
  return unless ($name && defined($value));

  $domain  ||= $self->{DOMAIN} || $self->get_domain();
  $path    ||= $self->{PATH} || '/';

  my $str = $name."=$value; domain=$domain; path=$path";
  $str .= "; expires=". $expires->(time()+$max_age). "; max-age=".$max_age if $max_age;

  push @{$self->{R}->{headers_out}->{"Set-Cookie"}}, $str;
}

sub set_cookie_expired {
  my $self = shift;
  my ($name, $value, $domain, $path) = @_;
  $value  ||= '0';
  $domain ||= $self->get_domain();
  $path   ||= $self->{PATH};

  push(@{$self->{R}->{headers_out}->{"Set-Cookie"}}, $name."=$value; domain=$domain; path=$path; Max-Age=0; Expires=Fri, 01-Jan-1980 01:00:00 GMT");
}


sub get_ip {
  my $self = shift;

  if ( ($ENV{REMOTE_ADDR} =~ /^192\.168\./ or $ENV{REMOTE_ADDR} =~ /^10\./)
    and $ENV{HTTP_X_FORWARDED_FOR}
    and ($ENV{HTTP_X_FORWARDED_FOR} =~ /(\d+\.\d+\.\d+\.\d+)$/)) {
    return $1;
  }

  $ENV{REMOTE_ADDR} =~ /(\d+\.\d+\.\d+\.\d+)$/;
  return $1;
}

sub get_ip_int {
  my $self = shift;

  return unpack("N", pack("C4", split(/\./, $self->get_ip())))
}

sub get_method {
  my $self = shift;

  return $ENV{REQUEST_METHOD};
}

sub get_ua {
  my $self = shift;

  return $ENV{HTTP_USER_AGENT};
}

sub get_referer {
  my $self = shift;

  return $ENV{HTTP_REFERER};
}

sub get_domain {
  my $self = shift;

  return $self->{DOMAIN} || $self->get_servername();
}

sub get_when {
  my $self = shift;

  return time();
}

sub is_oauth {
  my $self = shift;

  return ($ENV{HTTP_AUTHORIZATION} && $ENV{HTTP_AUTHORIZATION} =~ /^\s*OAuth\s(.*)$/i);
}

1;
