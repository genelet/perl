package Genelet::Cache;

use strict;
use File::Find;

my $copy_m = sub {
  my $m = shift;

  my $newm = {};
  while (my ($k, $v) = each %$m) {
    $newm->{$k} = $v;
  }

  return $newm;
};

my $copy_p = sub {
  my $p = shift;

  my $newp = [];
  for my $v (@$p) {
    push @$newp, (ref($v) eq 'ARRAY') ? [$v->[0]] : $v;
  }

  return $newp;
};

my $add_m = sub {
  my $lastm = shift;
  my $m = shift;
  return unless ($lastm or $m);

  my $newm = {};
  while (my ($k, $v) = each %$lastm) {
    $newm->{$k} = $v;
  }
  while (my ($k, $v) = each %$m) {
    $newm->{$k} = $v;
  }

  return $newm;
};

my $add_p = sub {
  my $lastp = shift;
  my $p = shift;
  return unless ($lastp or $p);

  my $newp = [];
  for my $v (@$lastp, @$p) {
    push @$newp, (ref($v) eq 'ARRAY') ? [$v->[0]] : $v;
  }

  return $newp;
};

my $init = sub {
  my $routes = shift;
  my $metrix = shift;
  my $expire = shift;
  my $expireall = shift;

  cache_build($_, $metrix, $expire, $expireall, $routes->{$_}) for (keys %$routes);

  return;
  sub cache_build {
    my ($cachetop, $metrix, $expire, $expireall, $route, $lastm, $lastp) = @_;
    my $m;
    my @a = split /\//, $route->{pathinfo}, -1;
    my $gmark = pop(@a) if ($a[-1] eq '_gmark');
    for my $var (qw(role component action tag type clientcache timeout)) {
      $m->{$var} = $route->{$var} if defined $route->{$var};
    }

    my $p;
    push(@$p, @a) if @a;
    my $newm = $add_m->($lastm, $m);
    my $newp = $add_p->($lastp, $p);

    if ($route->{expireall} && $newm->{role}) {
      my $str = '';
      my $found = 1;
      for my $item (@$lastp) {
        if (ref($item) eq 'ARRAY') {
          $str .= $item->[0] . '/';
        } elsif ($newm->{$item}) {
          $str .= $newm->{$item} . '/';
        } else {
          $found = 0;
          last;
        }
      } 
      push(@{$expireall->{$newm->{role}}}, [$cachetop.$str, $route->{expireall}]) if $found;
    }

    unless ($gmark) {
      if ($route->{expire}) {
        push(@{$expire->{join('_', @{$_})}}, [$cachetop, $newm->{tag}, $newm->{type}, @{$copy_p->($newp)}]) for (@{$route->{expire}}); # arrayref as key
      }
      $newm->{path} = [$cachetop, @$newp];
      $metrix->{$newm->{role}.'_'.$newm->{component}.'_'.$newm->{action}} = $newm;
      delete $newm->{$_} for qw(role component action);
      return;
    }

    cache_build($cachetop, $metrix, $expire, $expireall, $route->{$gmark}->{$_}, $newm, $newp ? [@$newp, [$_]] : [[$_]]) for (keys %{$route->{$gmark}});
  };
};
 
sub new {
  my ($class, %args) = @_;
  my $self  = {};

  $self->{DOCUMENT_ROOT} = $args{document_root};
  return unless $self->{DOCUMENT_ROOT};

  $self->{ROUTES} = $args{routes};
  $self->{METRIX} = $args{metrix};
  $self->{EXPIRE} = $args{expire};
  $self->{EXPIREALL} = $args{expireall};
  $self->{CURRENT} = $args{current};
  $self->{SCRIPT_NAME}    = $args{script_name};
  $self->{ACTION_NAME}    = $args{action_name};

  if ($self->{ROUTES} && !$self->{METRIX}) {
    $self->{METRIX} = {};
    $self->{EXPIRE} = {};
    $self->{EXPIREALL} = {};
    $init->($self->{ROUTES}, $self->{METRIX}, $self->{EXPIRE}, $self->{EXPIREALL});
  }

  bless $self, $class;
  return $self;
}

sub routes {
  my $self = shift;

  if (@_) {
    $self->{ROUTES} = shift;
    $self->{METRIX} = {};
    $self->{EXPIRE} = {};
    $self->{EXPIREALL} = {};
    $init->($self->{ROUTES}, $self->{METRIX}, $self->{EXPIRE}, $self->{EXPIREALL});
  }
  return $self->{ROUTES};
}

sub metrix {
  my $self = shift;

  $self->{METRIX} = shift if (@_);
  return $self->{METRIX};
}

sub expire {
  my $self = shift;

  $self->{EXPIRE} = shift if (@_);
  return $self->{EXPIRE};
}

sub expireall {
  my $self = shift;

  $self->{EXPIREALL} = shift if (@_);
  return $self->{EXPIREALL};
}

sub current {
  my $self = shift;

  $self->{CURRENT} = shift if (@_);
  return $self->{CURRENT};
}

sub document_root {
  my $self = shift;

  $self->{DOCUMENT_ROOT} = shift if (@_);
  return $self->{DOCUMENT_ROOT};
}

sub action_name {
  my $self = shift;

  $self->{ACTION_NAME} = shift if (@_);
  return $self->{ACTION_NAME};
}

sub script_name {
  my $self = shift;

  $self->{SCRIPT_NAME} = shift if (@_);
  return $self->{SCRIPT_NAME};
}

sub cache_file {
  my $self = shift;
  my ($ARGS) = @_;

  my $route = $self->{METRIX}->{join('_', @{$self->{CURRENT}})} if ($self->{CURRENT} && $self->{METRIX});
  return unless $route;

  my @path = @{$route->{path}};
  my $file = $self->{DOCUMENT_ROOT}.$path[0];

  for(my $i=1; $i<@path; $i++) {
    my $dir = (ref($path[$i]) eq 'ARRAY') ? $path[$i]->[0] : $ARGS->{$path[$i]};
    if ($i==(scalar(@path)-1)) {
      my $tag  = $route->{tag}  || $ARGS->{_gtag};
      my $type = $route->{type} || $ARGS->{_gtype};
      $file .= $dir ."_".$tag.".".$type;
    } else {
      $file .= $dir . "/";
      mkdir $file unless (-d $file);
    }
  }

  my @a;
  if (@a = stat $file) {
    if ($route->{timeout} && $a[9] && ($ARGS->{_gtime}-$a[9])>=$route->{timeout}) {
      unlink $file;
    } elsif ($a[9]) {
      push(@a, $route->{timeout}) if ($route->{clientcache} && $route->{timeout});
    }
  }

  return ($file, @a);
};

sub destroy {
  my $self = shift;
  my ($ARGS) = @_;

  my $routes = $self->{EXPIRE}->{join('_', @{$self->{CURRENT}})} if ($self->{CURRENT} && $self->{EXPIRE});
  return unless $routes;

  my ($files, $fails);
TOP: foreach my $path (@$routes) {
    my $file = $self->{DOCUMENT_ROOT}.$path->[0];
    my $tag = $path->[1];
    my $type= $path->[2];
    for(my $i=3; $i<@$path; $i++) {
      my $dir;
      if (ref($path->[$i]) eq 'ARRAY') {
        $dir = $path->[$i]->[0];
      } elsif (defined $ARGS->{$path->[$i]}) {
        $dir = $ARGS->{$path->[$i]};
      } else {
        next TOP;
      }
      if ($i==(scalar(@$path)-1)) {
        $tag  ||= $ARGS->{_gtag};
        $type ||= $ARGS->{_gtype};
        $file .= $dir ."_".$tag.".".$type;
      } else {
        $file .= $dir . "/";
      }
    }
    if (unlink $file) {
      push @$files, $file;
    } else {
      push @$fails, $file;
    }
  }

  return ($files, $fails);
}

sub destroyall {
  my $self = shift;
  my ($role, %hash) = @_;
  return unless ($role && $self->{EXPIREALL} && $self->{EXPIREALL}->{$role} && %hash);

  sub wanted { unlink; }
  foreach my $c (@{$self->{EXPIREALL}->{$role}}) {
    next unless ($c->[0] && $c->[1]);
    next if ($c->[0] eq '/' || $c->[0] =~ /\.\./);
    find(\&wanted, $self->{DOCUMENT_ROOT}.$c->[0].$hash{$c->[1]}) if $hash{$c->[1]};
  }
}

sub has_role {
  my $self = shift;
  my $path = shift;
  my $role = shift;

  return unless $self->{ROUTES};

  foreach my $lead (keys %{$self->{ROUTES}}) {
    if (substr($path, 0, length($lead)) eq $lead) {
      substr($path, 0, length($lead)) = '';
      my $route = $self->{ROUTES}->{$lead};
      return 1 if check_route_role($route, $path, $role);
    }
  }
  return;

  sub check_route_role {
    my ($route, $path, $role) = @_;

    return 1 if ($route->{role} && ($route->{role} eq $role));

    return unless $route->{pathinfo};
    my @vars = split '/', $route->{pathinfo}, -1;
    my @pars = split '/', $path, -1;
    while (my $var = shift @vars) {
      my $par = shift @pars;
      if ($var eq '_gmark') {
        foreach my $lead (keys %{$route->{_gmark}}) {
          next unless ($par eq $lead);
          $path = join('/', @pars);
          return 1 if check_route_role($route->{_gmark}->{$lead}, $path, $role);
        }
      }
    }
    return;
  }
}

sub rewrite {
  my $self = shift;
  my $path = shift;

  return unless $self->{ROUTES};

  my $found = 0;
  my $route;
  foreach my $lead (keys %{$self->{ROUTES}}) {
    #next unless (substr($lead, 0, 1) eq '/' && substr($lead, -1 ,1) eq '/');
    if (substr($path, 0, length($lead)) eq $lead) {
      $found = 1;
      substr($path, 0, length($lead)) = '';
      $route = $self->{ROUTES}->{$lead};
      last;
    }
  }
  return unless ($found && $path);
  my @pars = split '/', $path, -1;
  my $hash = {};
  my $reserve = {};
  my @names = split /\./, pop @pars, -1;
  $hash->{type} = pop @names if (@names>1);
  @names = split /_/, join('.', @names), -1;
  $hash->{tag}  = pop @names if (@names>1);
  push @pars, join('_', @names);

  my @features = qw(tag type role action component);
  url_values($hash, $reserve, $route, \@pars);
  for (@features) {
    $reserve->{$_} = $hash->{$_} unless defined $reserve->{$_};
    delete $hash->{$_};
  }

  return unless ($reserve->{role} && $reserve->{component} && $reserve->{action} && $reserve->{tag});

  my $q = "";
  while (my ($var, $par) = each %$hash) {
    next if ($var eq 'mark');
    $par =~ s/=/%3D/g;
    $par =~ s/&/%26/g;
    $q .= '&'.$var.'='.$par;
  }

  return join('/', $self->{SCRIPT_NAME}, $reserve->{role}, $reserve->{tag}, $reserve->{component}).'?'.$self->{ACTION_NAME}.'='.$reserve->{action}.$q.'&_gtype='.$reserve->{type};

  sub url_values {
    my ($hash, $reserve, $route, $pars) = @_; 

    my @features = qw(tag type role action component);
    for (@features) {
      $reserve->{$_} = $route->{$_} if defined $route->{$_};
    }

    my @vars = split '/', $route->{pathinfo}, -1;
    while (@vars) {
      my $var = shift @vars;
      my $varnew = $var;
      substr($varnew,0,2) = '' if ($var eq '_gmark');
      my $par = shift @$pars;
      $hash->{$varnew} = $par; 
      return url_values($hash, $reserve, $route->{$var}->{$par}, $pars) if ($var eq '_gmark');
    }

    return;
  }
}

sub read {
  my $self = shift;
  my $file = shift;

  local *GOUT;
  if (open(GOUT, $file)) {
    local $/ = undef;
    my $output = <GOUT>;
    close(GOUT);
    return $output;
  }

  return;
}

sub write {
  my $self = shift;
  my ($file, $output) = @_;

  local *GOUT;
  if (open(GOUT, ">".$file)) {
    print GOUT $output;
    close(GOUT);
    return 1;
  }

  return;
}

1;

__END__

=head1 NAME

Genelet::Cache - Create and destroy caches in Genelet

=head1 SYNOPSIS

 To create a new cache object:

 my $CONFIG  = ...;
 my $ARGS    = ...;
 my $content = ...;

 my $cache = Genelet::Cache->new(
    document_root => '/usr/local/apache/htdocs',
    routes        => $ROUTES);

 To define the current triplet:

 $cache->current(['vendor', 'product', 'edit']);

 To get the name of the cached file and its stats:

 my ($filename, @stats) = $cache->cache_file($ARGS);

 To write to and read from the cached file:

 my $rv = $cache->write($filename, $content);
 my $disk = $cache->read($filename);

 Or, rewrite the cached file to its original URI:

 $cache->script_name('/run.fcgi'); # constructor for script name
 $cache->action_name('action');    # constructor for action name
 my $url = $cache->rewrite('/cached/vendor/111/333_e.html');

=head1 DESCRIPTION

This module implements the C<Genelet::Cache> class, 
representing server's caching mapping.

=head1 CONSTRUCTORS

This method constructs a new C<Genelet::Cache> object:

my $cache = Genelet::Cache->new(
    document_root => '/usr/local/apache/htdocs',
    routes        => $ROUTES);

where document_root, which is mandatory, defines the root web location;
$ROUTES lists file patterns you want to cache and clean-up under the root,
explained in detail later.

You may pass the following getters and setters in the new() method.

=over 4 

=item $cache->routes(), get or set the configration hash.

=item $cache->metrix(), get or set server's caching map.

=item $cache->expire(), get or set server's cache destructing map.

=item $cache->document_root(), get or set the server root,

=item $cache->script_name(), get or set the current script or handler name

=item $cache->action_name(), get or set the action name

=back

=head1 OBJECT METHODS

=over 4

=item $cache->current(['role', 'component', 'action']),

in Genelet, every page or web form is represented by the triplet of
"role" (visitor type), "component" (database table or model name), 
and "action" (verb on the component). This method sets server's
current triplet.

=item my ($fn, @stats) = $cache->cache_file($ARGS),

gets the name and the stats of the cached file, that the current triplet 
maps to. $ARGS = {_gtag=>xxx, _gtype=>yyy, _gtime=>ddddd}, which is a hash,
may be required to build the file name. 
If the file already exists on disk, @stats returns 
a 13-element status info. There may be the 14th element for
the timeout (in seconds) if the client cache is enabled.
If it does not exist, the status array 
is empty. It it is staled due to timeout, 
it will be removed from the disk first.

When running this method, upline directories of the cache file
will be generated automatically.

If the method fails, it returns undef.

=item my ($oks, $fails) = $cache->destroy($ARGS),

destroys all cached files witin the current triplet.
$oks returns a list of successfully
deleted files and $fails failed or none-existent files.

If failed, it returns undef.

=item my $uri = $cache->rewrite($path),

return the dynamical URI (including
query string) from the cached file name $path,
relative to the document root. Return undef if fails. 

=item my $rv = $cache->write($filename, $content),

write the content to 
the caching file. Return 1 if successful, or undef if failed.

=item my $body = $cache->read($filename),

return the content of the cached file. Return undef if fails.

=back

=head1 CONFIGURATION

=over 4

The $ROUTES describes how cachings should be stored
on disk.

$ROUTES = {
  '/cache/' => {
      pathinfo=>'_gmark',
      clientcache=>0,
      timeout=>3600,
      _gmark => {
        'vendor' => {
          role=>'vendor',
          expireall=>'vendorid',
          pathinfo=>'vendorid/_gmark',
          _gmark => {'campaign'=>$c, 'item'=>$i},
        },
      },
  },
};

The keys, which starts and ends up with '/', are the top caching directories. In above example, there is only one key "/cache/". 
If a directory is located under the document root, 
you may need to protect it with authentication. 

Each value represents a recursive hash,
in which "clientcache", being 0 or 1, marks
whether or not the server should return client-site caching
headers; "role", "component", and "action" are
the current triplet; "expire" is a list of triplets that triggers
the removal of the cache; "tag" is the 
language tag, default to $ARGS->{_gtag};
"type" is the file type, default to $ARGS->{_gtag};
and "pathinfo" is the follow-up sub directory path,
seperated by '/'.

=back

=head2 File Path


=over 4

The names of the sub-directories are always
variable names, except for the special
marker "_gmark".
For example, in 'vendorid/_gmark',
"vendorid" is the variable name 
that will be replaced by its value in $ARGS in the filepath. 
If you don't want it to be replaced, use "_gmark"
and design it a value, called "gmark hash".
The keys of the hash are sub-directory names (strings).

Every sub-directory in "gmark hash" defines the next level of recursive 
mappings. For example, in the above example, the temporary $c
is given by

$c = {
  component=>'campaign',
  pathinfo=>'campaignid',
  action=>'edit',
  expire=>[
    ['campaign',  'vendor', 'update'],
    ['campaign',  'vendor', 'delete']],
};

If there is no "gmark hash", then the
"pathinfo" is assumed to be pointed to the final
caching file. The language tag will be appended to
the filename, and the extension is "type".

For example, a visitor of "vendorid=111"
is running action "edit" on component "campaign"
with "campaignid=222", then

The name of the cache file $cache->cache_file({vendorid=>111, campaignid=>222})
will be "/cache/vendor/111/222_e.html". And

=back

=head2 Expire Triplet


=over 4

$uri = $cache->expire("/cache/vendor/111/222_e.html")

will be "/run.fcgi/vendor/e/campaign?action=edit&vendorid=111&campaignid=222&_gtype=html".

The cached file will be deleted if the vendor updates or deletes the campaign.

=back

=head2 Expire All


=over 4

Finally, there is an optional key called "expireall". The value of "expireall"
defines a role ID. When the role logouts, all the records under this role ID will be destroyed.

=back

=cut
