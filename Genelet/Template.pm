package Genelet::Template;
#interface 

use strict;
use Template;

sub get_errorpage {
  my $self = shift;
  my $output_ref = shift;

  my $ARGS = $self->{ARGS};
  return $self->_get_template($ARGS, undef, undef, undef, $output_ref, $self->{TEMPLATE}."/".$ARGS->{_gwho}."/", "error.".$ARGS->{_gtag});
}

sub get_loginpage {
  my $self = shift;
  my ($output_ref, $args, $dir, $file) = @_;

  return $self->_get_template($args, undef, undef, undef, $output_ref, $dir, $file);
}

sub get_template {
  my $self = shift;
  my ($output_ref, $lists, $other, $file, $extra) = @_;

  my $ARGS = $self->{ARGS};
  return $self->_get_template($ARGS, $ARGS->{_gaction}, $lists, $other, $output_ref, $self->{TEMPLATE}."/".$ARGS->{_gwho}."/".$ARGS->{_gobj}."/", $file, $extra);
}

sub _get_template {
  my $self = shift;
  my ($ARGS, $action, $lists, $other, $output_ref, $dir, $file, $extra) = @_;

  my $tt = Template->new({INCLUDE_PATH=>$dir, RELATIVE => 1}) or return [1088, $Template::ERROR];

  my $hash = {$action => $lists} if ($action and $lists);
  for my $key (keys %$ARGS) {
    if ($key =~ /^_g(.+)$/) {
      my $real = $1;
      $hash->{GENELET}->{$real} = $ARGS->{$key} if (grep {$real eq $_} qw(uri role tag component action mime view type idname admin time when group raw));
    } else {
      $hash->{$key} = $ARGS->{$key};
    }
  }

  if ($other) {
    $hash->{$_} = $other->{$_} for (keys %$other);
  }
  if ($extra) {
    $hash->{$_} = $extra->{$_} for (keys %$extra);
  }

  $tt->process($file, $hash, $output_ref) or return [1087, "$file :".$tt->error()];

  return;
}

1;
