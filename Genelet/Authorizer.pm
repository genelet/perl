package Genelet::Authorizer;

use strict;
use URI::Escape;
use Genelet::CGI;
use Genelet::Base;

use vars qw(@ISA);
@ISA = qw(Genelet::CGI Genelet::Base);

# document_root script_name logger errors env
__PACKAGE__->setup_accessors(
  cache => undef,
  roles => undef,
  gates => undef,
  secret=> undef,

  project => undef,
  pubrole => undef,
);

sub role_from_statics {
  my $self = shift;
  my ($go_uri, $query) = @_;

  my $predefines = $self->{GATES};

  my $role;
  my $pre;

  for $role (keys %$predefines) {
    my $obj = $predefines->{$role};
    my $static = $obj->static() or next;
    foreach $pre (@$static) {
      my $leading;
      my $ppv = 0;
      if (ref($pre) eq 'ARRAY') {
        $ppv = 1;
        $leading = $pre->[0];
      } else {
        $leading = $pre;
      }
      my $len = length($leading);
      next unless (substr($go_uri,0,$len) eq $leading);
      if ($ppv) {
        substr($go_uri,0,$len) = '';
        return unless $go_uri;

        my @parts = split /\//, $go_uri, -1;
        my $end = pop @parts; # in ppv, the last is the index or file
        my @types = split('.', $end);
        my $type = pop @types if (@types>1);

        my %hash;
        my $idname = $pre->[1];
        $hash{$idname} = $parts[$pre->[2]];
        my $stamp = $pre->[3];
        my $md5 = $pre->[4];
        if ($stamp && $md5 && $query) {
          foreach my $item (split('&', $query, -1)) {
            if ($item =~ /^$stamp=(.*)$/) {
              $hash{$stamp} = $1;
            } elsif ($item =~ /^$md5=(.*)$/) {
              $hash{$md5} = $1;
            } 
          }
        }
        if (@$pre>4) {
          $hash{is_open} = grep {$_ eq $type} (@$pre)[4..(scalar(@$pre)-1)];
        }
        return wantarray ? ($role, $hash{is_open}, $idname, $hash{$idname}, $hash{$stamp}, $hash{$md5}) : $role;
      } else {
        return $role;
      }
    }
  }

  return;
}

sub authorizer_status {
  my $self = shift;
  my ($go_uri) = @_;
  
  if ($self->{CACHE}) {
    if (-e $ENV{SCRIPT_FILENAME}) {
      return $self->send_status_authorizer(200);
    } elsif (my $dest = $self->{CACHE}->rewrite($go_uri)) {
      $self->warn("{Authorize}[Redirect]{url}1:$dest");
      $self->{R}->{headers_out}->{"Location"} = $dest;
      return $self->send_status_authorizer(200);
    } else {
      return $self->send_status_authorizer(404);
    }
  }

  return $self->send_status_authorizer(200);
}

sub run {
  my $self = shift;

  my $logger = $self->{LOGGER};
  $logger->screen_start($ENV{REQUEST_METHOD}, ($ENV{REDIRECT_REQUEST_URI} && $ENV{REDIRECT_REQUEST_URI} eq $ENV{REQUEST_URI}) ? $ENV{SCRIPT_NAME}.$ENV{PATH_INFO}."?".$ENV{QUERY_STRING} : $ENV{REQUEST_URI}, $ENV{REMOTE_ADDR}, $ENV{HTTP_USER_AGENT}) if ($logger && $logger->is_warn() && $logger->can('screen_start'));

  return ($ENV{FCGI_ROLE} && ($ENV{FCGI_ROLE} eq 'AUTHORIZER'))
	? $self->authorizer()
	: $self->send_status_page(401, "No authorizer");
}

sub authorizer {
  my $self = shift;

  $self->warn("{Authorize}[Static]{start}1");
  my $go_uri = uri_unescape($ENV{REQUEST_URI});
  my ($role, @id) = $self->role_from_statics($go_uri, $ENV{QUERY_STRING});
  unless ($role) {
	if ($self->{CACHE} && $self->{CACHE}->has_role($go_uri, $self->{PUBROLE})) {
      $self->warn("{Authorize}[Name]{role}$self->{PUBROLE}");
      $self->warn("{Authorize}[Static]{end}1");
      return $self->authorizer_status($go_uri);
    }
    # anything other than 200 is forced to be 401 in FCGI!
    return $self->send_status_authorizer(401);
  }
  $self->warn("{Authorize}[Name]{role}$role");

  my $gate = $self->{GATES}->{$role};
  $gate->r($self->{R}) if $gate;
  $self->warn("{Authorize}[Ticket]{start}1");
  my $status = $gate->verify_cookie();
  $self->warn("{Authorize}[Ticket]{end}1:$status");
  if ($status) {
    return $gate->forbid($status, 200, $role); # login page
  } elsif (@id) {
    $self->warn("{Authorize}[Name]{login}".$gate->auth()->{"X-Forwarded-User"});
    my $found = $id[0];
    unless ($found) {
      my $attributes = $self->{ROLES}->{$role}->{attributes}; 
      my @groups = split /\|/, $gate->auth()->{"X-Forwarded-Group"};
      my $i=0;
      while (my $attribute = $attributes->[$i]) {
        my $value = ($i) ? $groups[$i-1] : $gate->auth()->{"X-Forwarded-User"};
        $i++;
        if (($id[1] eq $attribute) && ($id[2] eq $value)) {
          $found = 1;
          last;
        }
      }
    }
    unless ($found) { 
      $found = 1 if ($id[3] && $id[4] && $self->digest($self->{SECRET}, $gate->auth()->{"X-Forwarded-Hash"}.$id[3]) eq $id[4]);
    }
    if ($found) {
      $self->warn("{Authorize}[PPV]{OK}1:");
    } else {
      $self->warn("{Authorize}[PPV]{OK}0:");
      return $gate->forbid(1020, 200, $role); # login page
    }
  }
  $self->warn("{Authorize}[Static]{end}1");

  return $self->authorizer_status($go_uri);
}


1;
