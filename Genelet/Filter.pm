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
	default_action => 'dashboard',
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
		sms  => ['_gsms', 'send_sms'],
	},
);

sub send_blocks {
  my $self = shift;
  my ($lists, $other) = @_;

  my $ARGS = $self->{ARGS};
  my $err;

  while (my ($MAIL, $value) = each %{$self->{BLOCKED}}) {
    my $gmail = $value->[0];
    my $send  = $value->[1];
    my $pars = $self->{BLKS}->{$MAIL};
    next unless ($pars && $ARGS->{$gmail});
    foreach my $envelope ((ref($ARGS->{$gmail}) eq 'ARRAY') ? @{$ARGS->{$gmail}} : $ARGS->{$gmail}) {
      $self->warn("{Filter}[$MAIL]{start}1");
      my $outmail = $envelope->{content};
      if ($outmail) {
        $self->info("$MAIL has Content");
      } else {
        return 1062 unless $envelope->{file};
        $self->info("$MAIL Template: ".$envelope->{file});
        $outmail = '';
        $err = $self->get_template(\$outmail, $lists, $other, $envelope->{file}, $envelope->{extra})
  and return $err;
      }
      return 1061 unless $outmail;
      while (my ($key, $val) = each %{$envelope}) {
        next if (grep {$key eq $_} qw(file content callback extra));
        $pars->{$key} = $val;
      }
      $err = $self->$send($pars, $outmail);
      $envelope->{callback}->($err) if ($err and $envelope->{callback});
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
  my $err = ($case eq 'as') ? $ticket->get_login_cookie_as(@_) : $ticket->get_login_cookie(@_);
  return $err if $err;

  $self->{R}->{headers_out} = $ticket->r()->{headers_out};
  return;
}

sub get_action {
  my $self = shift;
  my $action_name = shift;

  my $action = $self->{R}->param($action_name) || $self->{DEFAULT_ACTION};
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
  my ($dbh, $form, $extra, $nextextras) = @_;

  return;
}

sub after {
  my $self = shift;
  my ($form, $lists) = @_;

  return;
}
 
1;
__END__
