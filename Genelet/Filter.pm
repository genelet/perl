# pass in: r
# pass in in derived class: actions fks
# pass in: args
# totally 4 variables
package Genelet::Filter;

use strict;
use Genelet::Base;

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
  my $ARGS   = $self->{ARGS};
  my ($roleid, $value) = @_;

  return $self->digest($self->{SECRET}, $ARGS->{_gwhen}.$ARGS->{g_role}.$roleid.$value);
}
 
sub send_blocks {
  my $self = shift;
  my ($lists, $other) = @_;

  my $err;

  foreach my $gmail (keys %{$self->{BLKS}}) {
    my $hash = $self->{BLKS}->{$gmail};
    my $obj  = $other->{$gmail};
    next unless ($hash && $obj);
    foreach my $envelope ((ref($obj) eq 'ARRAY') ? @{$obj} : $obj) {
      $self->warn("{Filter}[$gmail]{start}1");
      my $outmail = $envelope->{Content};
      if ($outmail) {
        $self->info("$gmail has content");
      } else {
        return 1062 unless $envelope->{File};
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

sub set_login_cookie {
  my $self = shift;
  return $self->_set_login_cookie(undef, @_);
}

sub set_login_cookie_as {
  my $self = shift;
  return $self->_set_login_cookie('as', @_);
}

sub _set_login_cookie {
  my $self = shift;
  my $case = shift;
  my $role = shift;
# @_ is login, password and url

  my $provider = $self->{R}->param($self->{PROVIDER_NAME}) || 'db';
  my $ticket = $self->{DBIS}->{$role}->{$provider};
  my $err = ($case eq 'as') ? $ticket->set_login_cookie_as(@_) : $ticket->set_login_cookie(@_);
  return $err if $err;

  $self->{R}->{headers_out} = $ticket->r()->{headers_out};
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

  return unless $self->{ONCEPAGES};
  my $nextpages = $self->{ONCEPAGES}->{$self->{ARGS}->{g_action}} or return;

  my $i = 0;
  foreach my $page (@$nextpages) {
    my $err = $form->call_once($page, $_[$i]);
    return $err if $err;
    $i++;
  }

  return;
}
 
1;
__END__
