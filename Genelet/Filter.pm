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
	escs => undef,
	blks => undef,
	blocked    => {
		mail => ['_gmail', 'send_mail'],
		apns => ['_gapns', 'send_apns'],
		gcm  => ['_ggcm',  'send_gcm'],
		sms  => ['_gsms',  'send_sms'],
	},
);

sub send_blocks {
  my $self = shift;
  my ($lists, $other) = @_;

  my $err;

  while (my ($MAIL, $value) = each %{$self->{BLOCKED}}) {
    my $gmail = $value->[0];
    my $obj = $other->{$gmail};
    my $send  = $value->[1];
    my $pars = $self->{BLKS}->{$MAIL};
    next unless ($pars && $obj);
    foreach my $envelope ((ref($obj) eq 'ARRAY') ? @{$obj} : $obj) {
      $self->warn("{Filter}[$MAIL]{start}1");
      my $outmail = $envelope->{Content};
      if ($outmail) {
        $self->info("$MAIL has Content");
      } else {
        return 1062 unless $envelope->{File};
        $self->info("$MAIL Template: ".$envelope->{File});
        $outmail = '';
        $err = $self->get_template(\$outmail, $lists, $other, $envelope->{File}, $envelope->{Extra})
  and return $err;
      }
      return 1061 unless $outmail;
      while (my ($key, $val) = each %{$envelope}) {
        next if (grep {$key eq $_} qw(File Content Callback Extra));
        $pars->{$key} = $val;
      }
      $err = $self->$send($pars, $outmail);
      $envelope->{Callback}->($err) if ($err and $envelope->{Callback});
      $self->warn("{Filter}[$MAIL]{end}1:",$err);
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
  my ($form, $extra, $nextextras) = @_;

  return;
}

sub after {
  my $self = shift;
  my ($form) = @_;

  return;
}
 
1;
__END__
