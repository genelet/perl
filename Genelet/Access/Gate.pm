package Genelet::Access::Gate;

use Genelet::CGI;
use Genelet::Access;
our @ISA = qw(Genelet::CGI Genelet::Access);

__PACKAGE__->setup_accessors(
  erases     => undef,
  logout     => "/",
);

sub handler_logout {
  my $self = shift;
  my ($role, $tag) = @_;
  my $r = $self->{R};

  my @dirs = ($self->{SURFACE}, $self->{SURFACE}."_", $self->{GO_PROBE_NAME});
  push(@dirs, @{$self->{ERASES}}) if $self->{ERASES};
  $self->set_cookie_expired($_) for @dirs;

  my $chartag = $self->{CHARTAGS}->{$tag} if ($self->{CHARTAGS} && $tag);
  if ($chartag && $chartag->{Case}>0) {
    $r->{headers_out}->{"Content-Type"} = $chartag->{"Content_type"};
    if ($chartag->{Short} eq 'jsonp') {
      my $callback = $r->param($self->{CALLBACK_NAME}) || $self->{CALLBACK_NAME};
      return $self->send_nocache($callback.'("data":"'.$chartag->{logout}.'"})');
    } else {
      $r->{"Access-Control-Allow-Origin"} = $ENV{HTTP_ORIGIN} || '*';
      $r->{"Access-Control-Allow-Credentials"} = 'true';
      return $self->send_nocache('{"data":"'.$chartag->{logout}.'"}');
    }
  }

  $r->{headers_out}->{"Location"} = $self->{LOGOUT};
  return $self->send_status_page(303);
}

sub reset_gate {
  my ($self, $attrs, $hash) = @_;

  my $value = [];
  my $i = [];
  while (my ($k, $v) = each %$hash) {
    my $j = -1;
    for my $item (@$attrs) {
      if ($item eq $k) {
        push @$i, $j;
        push @$value, $v;
        last;
      }
      $j++;
    }
  }

  my $signed = $self->reset_signature($value, $i);
  return "signature not found." unless $signed;
  $self->set_cookie($self->{SURFACE}."_", $signed);
  $self->set_cookie($self->{SURFACE}, $signed, $self->{MAX_AGE}) if $self->{MAX_AGE};

  return;
}

1;
