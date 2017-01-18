package Genelet::Scoder;

use strict;
use MIME::Base64;

use vars qw(@ISA @EXPORT);

use Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(scoder encode_scoder decode_scoder);

sub scoder {
  my ($text, $CRYPTEXT) = @_;

  my $len      = length($CRYPTEXT);
  my @cryptext = map {ord($_)} (split('', $CRYPTEXT));

  my $mycrypt = sub {
    my ($buf, $i) = @_;

    $buf ^= 255 & ($cryptext[$i] ^ ($cryptext[0]*$i));
    $cryptext[$i] += ($i<($len-1)) ? $cryptext[$i+1] : $cryptext[0];
    $cryptext[$i] += 1 unless $cryptext[$i];
    $i= 0 if (++$i >= $len);
    return ($buf, $i);
  };

  my @out;
  my $cnew;
  my $k = $len/2;
  for my $c (split('',$text)) {
    ($cnew, $k) = $mycrypt->(ord($c), $k);
    push @out, $cnew;
  }

  return join('', map {chr($_)} @out);
}

sub encode_scoder {
  my ($text, $CRYPTEXT) = @_;
  return unless (defined($text) && $CRYPTEXT);

  return encode_base64url(scoder($text, $CRYPTEXT));
}

sub decode_scoder {
  my ($text, $CRYPTEXT) = @_;
  return unless (defined($text) && $CRYPTEXT);

  return scoder(decode_base64url($text), $CRYPTEXT);
}

sub encode_base64url {
  my $e = encode_base64(shift, "");
  $e =~ s/=+\z//;
  $e =~ tr[+/][-_];
  return $e;
}

sub decode_base64url {
  my $s = shift;
  $s =~ tr[-_][+/];
  $s .= '=' while length($s) % 4;
  return decode_base64($s);
}

1;
