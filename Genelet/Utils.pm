package Genelet::Utils;

use strict;
use File::Basename;
use Time::Local;
use vars qw(@ISA @EXPORT);

use Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(ipint ipstr randompw unix_from_now now_from_unix day_from_unix usday_from_unix day_for_tomorrow rfc822_time upload_field dimensions bits2total total2bits bits2filters);

my $quick2 = sub { # 2^n - 1
  my $bit = shift or return 0;

  my $p=1;
  $p = 1 + ($p<<1) while (--$bit);
  return $p;
};

sub bits2total {
  my ($values, $bits) = @_;
  my $n = scalar(@$bits);

  my $total = 0;
  for (my $i=$n-1; $i>=0; $i--) {
    $total += $values->[$i] & $quick2->($bits->[$i]);
    $total <<= $bits->[$i-1] if ($i!=0);
  }
  return $total;
}

sub total2bits {
  my ($total, $bits) = @_;
  my $n = scalar(@$bits);

  my $values;
  for (my $i=0; $i<$n; $i++) {
    $values->[$i] = $total & $quick2->($bits->[$i]);
    $total >>= $bits->[$i] if ($i!=($n-1));
  }
  return $values;
}

sub bits2filters {
  my ($bits) = @_;
  my $n = scalar(@$bits);

  my $filters;
  my $end = 0;
  for (my $i=0; $i<$n; $i++) {
    $filters->[$i]->[0] = $end; 
    $filters->[$i]->[1] = $quick2->($bits->[$i]);
    $end += $bits->[$i];
  } 

  return $filters;
}

sub ipint {
  return unpack("N", pack("C4", split(/\./, shift)));
}
sub ipstr {
  return sprintf("%d.%d.%d.%d", unpack("C4", pack("N", shift)));
}

sub randompw {
  my $len = shift || 8;
  my @chars = ('a'..'z', '0'..'9');
  my $num = scalar @chars;

  return join('', map {$chars[$num * rand()]} (1..$len));
}

sub unix_from_now {
  my $gmt = shift;

  return unless ($gmt =~ /^(\d{1,4})-(\d\d?)-(\d\d?) (\d\d?):(\d\d?):(\d\d?)$/);
  my $year  = $1,
  my $month = $2;
  my $day   = $3;
  my $hour  = $4,
  my $minute = $5,
  my $second = $6,
  substr($month,0,1)  = '' if (substr($month,0,1)  eq '0');
  substr($day  ,0,1)  = '' if (substr($day  ,0,1)  eq '0');
  substr($hour, 0,1)  = '' if (substr($hour, 0,1)  eq '0');
  substr($minute,0,1) = '' if (substr($minute,0,1) eq '0');
  substr($second,0,1) = '' if (substr($second,0,1) eq '0');

  return timelocal($second,$minute,$hour,$day,$month-1,$year);
}

sub now_from_unix {
  my $t = shift || time();
  my ($s,$m,$h,$da,$mo,$ye) = localtime($t);
  return ($ye+1900)."-".($mo+1)."-$da $h:$m:$s";
}

sub day_from_unix {
  my $t = shift || time();
  my ($da,$mo,$ye) = (localtime($t))[3..5];
  return ($ye+1900)."-".($mo+1)."-$da";
}

sub usday_from_unix {
  my $t = shift || time();
  my ($da,$mo,$ye) = (localtime($t))[3..5];
  my @m = qw(January February March April May June July August September October November December);
  return $m[$mo]." $da, ".($ye+1900);
}

sub day_for_tomorrow {
  my $t = shift || day_from_unix();

  my ($ye,$mo,$da) = split '-', $t, 3;
  substr($mo,0,1) = '' if (substr($mo,0,1) eq '0'); 
  substr($da,0,1) = '' if (substr($da,0,1) eq '0'); 
  ($da,$mo,$ye) = (localtime(timelocal(1,0,0,$da,$mo-1,$ye)+24*3600))[3..5];
  $mo++;
  $ye+=1900;
  $mo = "0$mo" if ($mo<10);
  $da = "0$da" if ($da<10);
  return $ye."-".$mo."-$da";
}
    
sub rfc822_time {
  my $t = shift || time();

  my @weeks = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  my @months = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

  my ($sec, $min, $hour, $d, $m, $y, $w) = localtime($t);
  return sprintf("%s, %02d %s %04d %02d:%02d:%02d PST", $weeks[$w], $d, $months[$m], $y+1900, $hour, $min, $sec);
}

# [must] r: request object, field: file upload form field, dir: directory to store the file, 
# [optional] name: name of the resultant file on server, ext_guess: guess extension
sub upload_field {
  my $r = shift;
  my ($field, $dir, $name, $ext_guess) = @_;

  my $upload_fh = $r->upload($field);
  my $upload    = $r->param($field);
  return unless ($dir && $upload && $upload_fh);

  if (!$name or $ext_guess) {
    my ($orig, $pre, $ext);
    File::Basename::fileparse_set_fstype(
      ($ENV{HTTP_USER_AGENT} =~ /(bsd)|(inux)|(nix)/)?"Unix":"MSWin32");
    ($orig, $pre, $ext) = File::Basename::fileparse($upload, '\.\w+');
    $orig =~ s/\s+//g;
    return unless $orig;
    $name ||= $orig;
    if ($ext_guess) {
      $name .= $ext;
    } else {
      $name = $orig.$ext;
    }
  }

  my $ret = open(FH, ">$dir/$name");
  unless ($ret) {
    warn ">$dir/$name:" . $!;
    return;
  }
  my ($bytesread, $buffer);
  while ($bytesread = read($upload_fh, $buffer, 1024)) {
    print FH $buffer;
  }
  close(FH);

  return $name;
}

sub dimensions {
  my $buf;
  my $height;
  my $width;
  local *IMAGE;

  open(IMAGE, "<".shift()) || return;
  return if (read(IMAGE, $buf, 2) < 2);
  if ($buf eq "GI") {
    return if (read(IMAGE, $buf, 8) < 8);
    if (substr($buf, 0, 1) eq "F") {
      ($width, $height) = unpack("vv", substr($buf, 4, 4));
      return {width=>$width, height=>$height, type=>'gif'};
    }
  } elsif ($buf eq "\377\330") {
    my $mk;
    my $len;

    for (;;) {
      do {
        return if (read(IMAGE, $buf, 1) < 1);
      } while ($buf ne "\377");
      while ($buf eq "\377") {
        return if (read(IMAGE, $buf, 1) < 1);
      }
      $mk = unpack("C", $buf);
      return if (read(IMAGE, $buf, 2) < 2);
      $len = unpack("n", $buf);
      if (($mk >= 0xC0 && $mk <= 0xC3) || ($mk >= 0xC5 && $mk <= 0xC7) || ($mk >= 0xC9 && $mk <= 0xCB) || ($mk >= 0xCD && $mk <= 0xCF)) {
        return if ($len < 7);
        return if (read(IMAGE, $buf, $len - 2) < $len - 2);
        ($height, $width) = unpack("nn", substr($buf, 1, 4));
        return {width=>$width, height=>$height, type=>'jpg'};
      } else {
        seek(IMAGE, $len - 2, 1) || return;
      }
    }
  } elsif ($buf eq "\211P") {
    return if (read(IMAGE, $buf, 22) < 22);
    if (substr($buf, 0, 6) eq "NG\015\012\032\012") {
      ($width, $height) = unpack("NN", substr($buf, 14, 8));
      return {width=>$width, height=>$height, type=>'png'};
    }
  } elsif ($buf eq "BM") {
    my $mk;
    return if (read(IMAGE, $buf, 14) < 14);
    $mk = unpack("v", substr($buf, 12, 2));
    if ($mk == 12) {
      return if (read(IMAGE, $buf, 6) < 6);
      ($width, $height) = unpack("vv", substr($buf, 2, 4));
    } elsif ($mk == 40 || $mk == 64) {
      return if (read(IMAGE, $buf, 10) < 10);
      ($width, $height) = unpack("VV", substr($buf, 2, 8));
    } else {
      return;
    }
    return {width=>$width, height=>$height, type=>'bmp'};
  }
  return;
}

1;
