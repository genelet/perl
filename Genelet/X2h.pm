package Genelet::X2h;

use strict;
use XML::LibXML;

sub x2h {
  my $self = shift;
  my $doc = shift;

  my $init = {
	attr  => '-',
	text  => '#text',
	cdata => undef,
	comm  => undef
  };

  my $res;
  if ($doc->hasChildNodes or $doc->hasAttributes) {
    $res = {};
    for ($doc->attributes) {
      $res->{ $init->{attr} . $_->nodeName } = $_->getValue;
    }
    for ($doc->childNodes) {
      my $ref = ref $_;
      my $nn;
      if ($ref eq 'XML::LibXML::Text') {
        $nn = $init->{text}
      } elsif ($ref eq 'XML::LibXML::CDATASection') {
        $nn = defined $init->{cdata} ? $init->{cdata} : $init->{text};
      } elsif ($ref eq 'XML::LibXML::Comment') {
        $nn = defined $init->{comm} ? $init->{comm} : next;
      } else {
        $nn = $_->nodeName;
      }
      my $chld = _x2h($_);
      if (exists $res->{$nn} ) {
        $res->{$nn} = [ $res->{$nn} ] unless ref $res->{$nn} eq 'ARRAY';
        push @{$res->{$nn}}, $chld if defined $chld;
      } else {
        if ($nn eq $init->{text}) {
          $res->{$nn} = $chld if length $chld;
        } else {
          $res->{$nn} = $chld;
        }
      }
    }
    delete $res->{ $init->{text} } if keys %$res > 1 and exists $res->{ $init->{text} } and !length $res->{ $init->{text} };
    return $res->{ $init->{text} } if keys %$res == 1 and exists $res->{ $init->{text} };
  } else {
    $res = $doc->textContent;
    $res =~ s{^\s+}{}s;
    $res =~ s{\s+$}{}s;
  }

  return $res;
}

1;
