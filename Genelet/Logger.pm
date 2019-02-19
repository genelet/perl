package Genelet::Logger;

use strict;
use Data::Dumper;
$Data::Dumper::Terse = 1;

my @LEVELS = qw(emergency alert critical error warn notice info debug);
my %RLEVELS = (emergency=>0, alert=>1, critical=>2, error=>3, 'warn'=>4, notice=>5, info=>6, debug=>7);

sub new {
  my ($class, %args) = @_;
  my $self  = {};

  $self->{CURRENT_MSG} = '';
  $self->{MINLEVEL} = 0;
  $self->{MAXLEVEL} = 0;
  $self->{CURRENT_LEVEL} = 0;
  $self->{TRACE} = $args{trace};
  $self->{FILENAME} = $args{filename};

  $self->{MINLEVEL} = $RLEVELS{$args{minlevel}} if (defined($args{minlevel}) && $args{minlevel} !~ /^\d$/);
  $self->{MAXLEVEL} = $RLEVELS{$args{maxlevel}} if (defined($args{maxlevel}) && $args{maxlevel} !~ /^\d$/);
  
  bless $self, $class;
  return $self;
}

sub minlevel {
  my $self = shift;

  $self->{MINLEVEL} = shift if (@_);
  return $self->{MINLEVEL};
}

sub maxlevel {
  my $self = shift;

  $self->{MAXLEVEL} = shift if (@_);
  return $self->{MAXLEVEL};
}

sub trace {
  my $self = shift;

  $self->{TRACE} = shift if (@_);
  return $self->{TRACE};
}

sub filename {
  my $self = shift;

  $self->{FILENAME} = shift if (@_);
  return $self->{FILENAME};
}

sub current_msg {
  my $self = shift;

  $self->{CURRENT_MSG} = shift if (@_);
  return $self->{CURRENT_MSG};
}

sub current_level {
  my $self = shift;

  $self->{CURRENT_LEVEL} = shift if (@_);
  return $self->{CURRENT_LEVEL};
}

sub screen_start {
  my $self = shift; 
  my $method = shift;
  my $uri = shift || '';
  my $ip = shift;
  my $ua = shift;

  return $self->warn("GENELET LOGGER {New Screen}{".time()."}{$ip}{$method}$uri $ua");
}

sub screen { 
  my $self = shift;

  my $str = '';
  my $in = 0;
  my $follow = 0;

  local *D;
  open(D, $self->{FILENAME}) || return;
  while (my $line = <D>) {
    if ($line =~ /^\[warn $$\]GENELET LOGGER {New Screen}(.*)/) {
      $str = $1."\n";
      $in = 1;
      $follow = 1;
    } elsif ($in && ($follow || $line =~ /^\[(\S+) $$\](.*)$/)) {
      $str .= $line;
      $follow = 1;
    } elsif ($line =~ /^\[\S+ \d+\]/) {
      $follow = 0;
    }
  }
  close(D);

  return $str;
}

my $copyto = sub {
  my $metrix = shift;

  my $old;
  for (qw(URI TIME METHOD UA IP)) {
    $old->{$_} = $metrix->{$_};
    delete $metrix->{$_};
  }

  foreach my $case (keys %$metrix) {
    foreach my $property (keys %{$metrix->{$case}}) {
      foreach my $parameter (keys %{$metrix->{$case}->{$property}}) {
        $old->{$case}->{$property}->{$parameter}->[0] = $metrix->{$case}->{$property}->{$parameter}->[0];
        $old->{$case}->{$property}->{$parameter}->[1] = $metrix->{$case}->{$property}->{$parameter}->[1];
      }
    }
  }

  return $old;
};

sub metrix {
  my $self = shift;
  my $ip = shift;
  my $ua = shift;
  my $N = shift||2;

  my @olds;
  my $metrix;
  my $in = 0;
  my $follow = 0;
  my $pid;

  local *D;
  open(D, $self->{FILENAME}) || return;
  while (my $line = <D>) {
    chomp $line;
    if ($line =~ /^\[warn (\d+)\]GENELET LOGGER \{New Screen\}\{(\d+)\}\{([\.\d]+)\}\{(GET|POST)\}(\S+) (.*)$/) {
      my ($PID, $TIME, $IP, $METHOD, $URI, $UA) = ($1, $2, $3, $4, $5, $6); 
      if (($ip && ($ip ne $IP)) || ($ua && ($ua ne $UA))) {
        $in=0;
        $follow=0;
        next;
      }
      if ($metrix) {
        unshift @olds, $copyto->($metrix);
        pop(@olds) if (@olds >=$N);
      }
      $pid = $PID;
      $metrix = {TIME=>$TIME, IP=>$IP, METHOD=>$METHOD, URI=>$URI, UA=>$UA};
      $in = 1;
      $follow = 1;
    } elsif ($in && ($follow || $line =~ /^\[(\S+) $pid\](.*)$/)) {
      if (my ($case, $property, $parameter, $rest) = $line =~ /^\[\S+ $pid\]{(\w+)}\[(\w+)\]{([ \w]+)}(.*)$/) {
        if ($rest =~ /\:\:/) {
          $metrix->{$case}->{$property}->{$parameter} = [$rest];
        } elsif (my ($value, undef, $note) = $rest =~ /^([^\:]+)(:(.*))?$/) {
          $metrix->{$case}->{$property}->{$parameter} = [$value, $note];
        }
      }
      #if (my ($case, $property, $parameter, $value, undef, $note) = $line =~ /^\[\S+ $pid\]{(\w+)}\[(\w+)\]{([ \w]+)}([^\:]+)(:(.*))?$/) {
      #  $metrix->{$case}->{$property}->{$parameter} = [$value, $note];
      #}
      $follow = 1;
    } elsif ($line =~ /^\[\S+ \d+\]/) {
      $follow = 0;
    }
  }
  close(D);

  return wantarray ? ($metrix, @olds) : $metrix;
}

sub emergency { return shift->_log(0, @_); }
sub alert     { return shift->_log(1, @_); }
sub critical  { return shift->_log(2, @_); }
sub error     { return shift->_log(3, @_); }
sub warn      { return shift->_log(4, @_); }
sub notice    { return shift->_log(5, @_); }
sub info      { return shift->_log(6, @_); }
sub debug     { return shift->_log(7, @_); }

sub _log {
  my $self = shift;
  my $level = shift;
 
  return unless ($self->{FILENAME} && $level>=$self->{MINLEVEL} && $level<=$self->{MAXLEVEL});
  $self->{CURRENT_LEVEL} = $level; 

  $self->{CURRENT_MSG} = '';
  for (@_) {
    $self->{CURRENT_MSG} .= (ref($_)) ? Dumper($_) : $_;
  }

  if ($self->{TRACE}) {
    my @callers;
    for (my $i=0; my @c = caller($i); $i++) {
      my %frame;
      @frame{qw/package filename line subroutine hasargs wantarray evaltext is_require/} = @c[0..7];
      push @callers, \%frame;
    }
    foreach my $i (reverse 0..$#callers) {
      $self->{CURRENT_MSG} .= "\n";
      $self->{CURRENT_MSG} .= " " x 4 . "CALL($i):";
      my $frame = $callers[$i];
      foreach my $key (qw/package filename line subroutine hasargs wantarray evaltext is_require/) {
        next unless defined $frame->{$key};
        $self->{CURRENT_MSG} .= " $key($frame->{$key})";
      }
    }
  }

  local *D;
  open(D, ">>".$self->{FILENAME}) || return;
  print D "[", $LEVELS[$level], " ", $$, "]", $self->{CURRENT_MSG}, "\n";
  close(D);

  return;
}

sub is_debug     {return shift->_is_log(7);}
sub is_info      {return shift->_is_log(6);}
sub is_notice    {return shift->_is_log(5);}
sub is_warn      {return shift->_is_log(4);}
sub is_error     {return shift->_is_log(3);}
sub is_critical  {return shift->_is_log(2);}
sub is_alert     {return shift->_is_log(1);}
sub is_emergency {return shift->_is_log(0);}

sub _is_log {
  my $self = shift;
  my $level = shift;

  return ($level >= $self->{MINLEVEL} && $level <= $self->{MAXLEVEL});
}

1;
