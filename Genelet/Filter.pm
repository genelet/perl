# pass in: r
# pass in in derived class: actions fks
# pass in: args
# totally 4 variables
package Genelet::Filter;

use strict;
use Genelet::Base;
use Genelet::Utils;

use vars qw(@ISA);
@ISA = ('Genelet::Base');

__PACKAGE__->setup_accessors(
	default_actions => undef,
	gate => undef,
	dbis => undef,
	args => undef,
	actions => undef,
	fks => undef,
	oncepages => undef,
	escs => undef,
);
  
sub sign {
  my $self = shift;
  my $ARGS = $self->{ARGS};
  my $stamp = $ARGS->{_gwhen};  #  switch to "shift"?

  my ($roleid, $value) = @_;

  return Genelet::Utils::token($stamp, $self->{SECRET}, $ARGS->{_gwho}.$roleid.$value);
}

sub sign_open {
  my $self = shift;
  my ($stamp, $str) = @_;

  return Genelet::Utils::token($stamp, $self->{SECRET}, $str);
}
  
sub check_sign {
  my $self = shift;
  my ($tk, $roleid, $value) = @_;

  my $ARGS = $self->{ARGS};
  return Genelet::Utils::check_token($tk, $self->{SECRET}, $ARGS->{_gwho}.$roleid.$value);
}

sub check_sign_open {
  my $self = shift;
  my ($tk, $str) = @_;

  return Genelet::Utils::check_token($tk, $self->{SECRET}, $str);
}
  
sub send_blocks {
  my $self = shift;
  my ($lists, $other) = @_;

  my $err;

  foreach my $gmail (keys %{$self->{BLKS}}) {
    my $hash = $self->{BLKS}->{$gmail};
    my $obj  = $other->{$gmail};
    next unless ($hash && $obj);
    foreach my $envelope ((ref($obj) eq 'ARRAY') ? @{$obj} : ($obj)) {
      $self->warn("{Filter}[$gmail]{start}1");
      my $outmail = $envelope->{Content};
      if ($outmail) {
        $self->info("$gmail has content");
      } else {
        return 1065 unless $envelope->{File};
        $self->info("$gmail Template: ".$envelope->{File});
        $outmail = '';
        $err = $self->get_template(\$outmail, $lists, $other, $envelope->{File}, $envelope->{Extra});
		return $err if $err;
      }
      return 1061 unless $outmail;
      foreach my $key (keys %{$envelope}) {
        my $val = $envelope->{$key};
        next if (grep {$key eq $_} qw(File Content Callback Extra));
        $hash->{$key} = $val;
      }
      $err = $self->send_mail($hash, $outmail);
      $envelope->{Callback}->($err) if ($err and $envelope->{Callback});
      $self->warn("{Filter}[$gmail]{end}1:",$err);
      return $err if $err;
    }
  }

  return;
}

sub get_action {
  my $self = shift;
  my $action_name = shift;

  my $action = $self->{R}->param($action_name);
  unless ($action) {
    $action = ($ENV{REQUEST_METHOD} eq "GET" and $self->{R}->{"_gid_url"})
	? $self->{DEFAULT_ACTIONS}->{"GET_item"} 
	: $self->{DEFAULT_ACTIONS}->{$ENV{REQUEST_METHOD}};
  }
  my $actions  = $self->{ACTIONS};
  return ($action, $actions->{$action}) if $actions->{$action};

  while (my ($key, $value) = each %$actions) {
    return ($key, $value) if (grep {$_ eq $action} @{$value->{aliases}});
  }

  return;
}

sub validate {
  my $self = shift;
  my $action = shift || $self->{ARGS}->{_gaction};

  my $validate = $self->{ACTIONS}->{$action}->{'validate'} or return;
  for my $field (@$validate) {
    return $field unless defined($self->{ARGS}->{$field});
  }

  return;
}

sub preset {
  my $self = shift;
  my $ARGS = $self->{ARGS};
  return if ($self->{PUBROLE} eq $ARGS->{_gwho});

  my $action = $ARGS->{_gaction};
  my $actionHash = $self->{ACTIONS}->{$action};

  if ( ($actionHash->{options} && grep($_ eq 'csrf', @{$actionHash->{options}})) or
       (grep($_ eq $ENV{REQUEST_METHOD}, qw(PUT POST DELETE)) && grep($_ eq $action, qw(insert update delete insupd)))
  ) {
    my $idname = $ARGS->{_gidname};
    my $tk = $ARGS->{$self->{CSRF_NAME}};
    return 1046 unless $tk;
    return 1047 unless $self->check_sign($tk, $idname, $ARGS->{$idname});
  }

  return;
}

sub before {
  my $self = shift;
  my ($form, $extra, $nextextras, $onceextras) = @_;

  return;
}

sub after {
  my $self = shift;
  my $form = shift;

  my $ARGS = $self->{ARGS};

  return unless $self->{ONCEPAGES};
  my $nextpages = $self->{ONCEPAGES}->{$self->{ARGS}->{g_action}} or return;

  my $i = 0;
  foreach my $page (@$nextpages) {
    my $err = $form->call_once($page, $_[$i]);
    return $err if $err;
    $i++;
  }

  unless ($self->{PUBROLE} eq $ARGS->{_gwho}) {
    my $idname = $ARGS->{_gidname};
    $form->{OTHER}->{$self->{CSRF_NAME}} = $self->sign($idname, $ARGS->{$idname});
  }

  return;
}
 
1;
__END__
