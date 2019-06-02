package Genelet::Controller;

use strict;
use URI::Escape;
use Storable qw(dclone);
use DBI ();
use JSON;
use Data::Dumper;
use Genelet::Base;
use Genelet::Utils;
$Data::Dumper::Terse = 1;

use vars qw(@ISA);
@ISA = ('Genelet::Base');

#xtags: key, one in the project; value, the standard special tag name 
__PACKAGE__->setup_accessors(
# project    => '',
  pubrole    => '',
  escape_esc => 1,
  roles      => {},
  shadows    => undef,

  json_lib   => 1,

  cache      => undef,
);

sub assign_fk {
  my $self = shift;
  my ($who, $ARGS, $fk, $stamp, $duration, $extra) = @_;
  my $roleid = $ARGS->{_gidname};

  my $name  = $fk->[0] or return;
  my $value = "";
  if (ref($name) eq 'ARRAY') {
    for (@$name) {
      my $val = $ARGS->{$_};
      return 1041 unless defined($val);
      $extra->{$_} = $val;
      $value .= $val;
    }
  } else {
    $value = $ARGS->{$name};
    return 1041 unless defined($value);
    $extra->{$name} = $value;
    # is fk is roleis, then already certified
    return if ($name eq $roleid);
  }

  my $secret = $self->{SECRET};
  return unless $secret;
  return 1054 unless $fk->[1]; # md5 name should , but not exist

  my $md5 = $ARGS->{$fk->[1]} or return 1055;
  return 1052 unless ($md5 eq $self->digest($secret, $stamp.$who.$ARGS->{$roleid}.$value));
  return 1053 if ($duration && $ARGS->{_gtime}>$stamp);

  return;
}

sub assign_fk_tobe {
  my $self = shift;
  my $lists = shift;
  my $fk = shift;
  return unless ($lists && @$lists);

  my $err = make_it($lists, $fk, $self->{SECRET}, @_);
  return $err if $err;

  $self->{FK_LEVEL} ||= 0;
  return if ($self->{FK_LEVEL}); # we stop at the top level, parallel mode

  my $new_fk = [@$fk];
  while ($new_fk->[4]) {
    ++$self->{FK_LEVEL};
    return 1056 unless (grep {$new_fk->[4] eq $_} keys %{$lists->[0]});
    shift @$new_fk; shift @$new_fk; shift @$new_fk;
    for my $item (@$lists) {
      $err = $self->assign_fk_tobe($item->{$new_fk->[1]}, $new_fk, @_);
      return $err if $err;
    }
  }

  return;
 
  sub make_it {
    my $the_lists = shift;
    my $fk = shift;
    my ($secret, $stamp, $who, $value_roleid, $escs) = @_;

    my $name = $fk->[2];
    my $is_array = (ref($name) eq 'ARRAY');
TOP: for my $item (@$the_lists) {
      my $value = "";
      if ($is_array) {
        for (@$name) {
          next TOP unless defined($item->{$_});
          $value .= $item->{$_};
        }
      } else {
        next TOP unless defined($item->{$name});
        $value = $item->{$name};
      }
      $item->{$fk->[3]} = $self->digest($secret, $stamp.$who.$value_roleid.$value);
      next unless $escs;
      for (@{$escs}) {
        $item->{$_."_esc"} = uri_escape_utf8($item->{$_}) 
			if defined($item->{$_});
      }
    }
    return;
  }
}

sub authhash {
  my $self = shift;
  my ($who, $auth) = @_;

  my %hash;
  @hash{@{$self->{ROLES}->{$who}->{attributes}}} = map {uri_unescape($_)} ($auth->{'X-Forwarded-User'}, split(/\|/, $auth->{'X-Forwarded-Group'}));
  return %hash;
}

sub handler {
  my $self = shift;
  my ($pathinfo, $gate) = @_;
  my $r = $self->{R};

  $self->warn("{Controller}[Name]{project}".$self->{PROJECT});

  my $cache = $self->{CACHE};

  my ($model, $who, $tag, $obj, $name) = split /\//, $pathinfo, -1;
  return $self->send_status_page(404) if ($name or !$obj);
  $name = join('', map {ucfirst(lc $_)} split('_', $obj));
  my $save = $name;

  $self->warn("{Controller}[OK]{good url}1");
  $self->warn("{Controller}[Name]{role}".$who);
  $self->warn("{Controller}[Name]{tag}".$tag);
  $self->warn("{Controller}[Name]{component}".$name);
  $self->warn("{Controller}[OK]{component list}1");

  $model   = $self->{PROJECT} . "::$name"."::Model";
  $name    = $self->{PROJECT} . "::$name"."::Filter";

  $self->warn("{Controller}[Filter]{start}1");
  my $filter = $name->new(gate=>$gate, map {($_, $self->{uc $_})} 
	qw(document_root script custom secret template errors
	dbis ua logger dbis r default_actions));
  return $self->send_status_page(404) unless $filter;
  $self->warn("{Controller}[Filter]{end}1");
  for my $att (qw(actions fks escs blks)) {
    my $ref = $self->{STORAGE}->{$save};
    $filter->$att(ref($ref->{$att}) ? dclone($ref->{$att}) : $ref->{$att}) if exists($ref->{$att});
  }
 
  my ($action, $actionHash) = $filter->get_action($self->{ACTION_NAME});
  return $self->send_status_page(404) unless ($action && $actionHash);
  $self->warn("{Controller}[Name]{action}".$action);

  my $ARGS;
  for my $par ($r->param()) {
    my @a;
    my %reference;
    for my $item ($r->param($par)) {
      $item =~ s/^\s+//;
      $item =~ s/\s+$//;
      next if ($item eq '' or $reference{$item});
      $reference{$item} = 1;
      push(@a, $item);
    }
    if (@a>1) {
      $ARGS->{$par} = \@a;
    } elsif (@a==1) {
      $ARGS->{$par} = $a[0];
      if ($self->{ESCAPE_ESC} && $par =~ /^(.*)_esc$/) {
        my $orig = $1;
        $ARGS->{$orig} = $ARGS->{$par};
        $ARGS->{$par} = uri_escape_utf8($ARGS->{$par});
      } 
    }
  }
  my $escs = $filter->escs() if $self->{ESCAPE_ESC};
  if ($escs) {
    $self->warn("{Controller}[Name]{Escs}start");
    for my $orig (@$escs) {
      $ARGS->{$orig."_esc"} ||= uri_escape_utf8($ARGS->{$orig}) if defined($ARGS->{$orig});
    }
    $self->warn("{Controller}[Name]{Escs}end");
  }
  $ARGS->{_guri}   = $pathinfo;
  $ARGS->{_gwho}   = $ARGS->{g_role} = $who;
  $ARGS->{_gtag}   = $ARGS->{g_tag} = $tag;
  $ARGS->{_gobj}   = $ARGS->{g_component} = $obj;
  $ARGS->{_gaction}= $ARGS->{g_action} = $action;
  $ARGS->{_gmime}  = $self->{CHARTAGS}->{$tag}->{"Content_type"};
  $r->{"headers_out"}->{"Content-Type"} = $ARGS->{_gmime};
  $ARGS->{_gtype}      = $self->{CHARTAGS}->{$tag}->{Short};
  $ARGS->{g_script}    = $self->{SCRIPT};
  $ARGS->{g_scriptfull}= $self->get_scriptfull();
  $ARGS->{g_query_string}= $self->get_query_string();
  $ARGS->{g_json_url}  = $self->get_json_url();
  $ARGS->{g_server}    = $self->get_servername();
  $ARGS->{_gidname}    = undef;
  $ARGS->{_gadmin}     = undef; 
  my %hash;
  if (my $role = $self->{ROLES}->{$who}) {
    my $auth = $gate->auth() if $gate;
    return $self->send_status_page(401) unless $auth;
    $ARGS->{_gidname} = $role->{id_name};
    $ARGS->{_gadmin}  = $role->{is_admin};
    $ARGS->{_gtype_id}= $role->{type_id};
    %hash = $self->authhash($who, $auth);
    $ARGS->{_gauthkeys} = [keys %hash];
    $ARGS->{$_} = $hash{$_} for @{$ARGS->{_gauthkeys}};
    $ARGS->{_gtime} = $auth->{'X-Forwarded-Request_Time'};
    $ARGS->{_gwhen} = $auth->{'X-Forwarded-Time'};
    $ARGS->{_gduration} = $auth->{'X-Forwarded-Duration'};
  } elsif ($self->{SHADOWS} && (my $real_who = $self->{SHADOWS}->{$who})) {
    my $auth = $gate->auth() if $gate;
    return $self->send_status_page(401) unless $auth;
    $ARGS->{$_} = $auth->{$_} for (keys %$auth);
    $ARGS->{_gshadow} = $who;
    $ARGS->{_gwho}  = $ARGS->{g_role} = $who = $real_who;
    my $role = $self->{ROLES}->{$who};
    return $self->send_status_page(404) unless $role;
    $ARGS->{_gidname} = $role->{id_name}; 
    $ARGS->{$ARGS->{_gidname}} = $auth->{oauth_user_id};
    $ARGS->{_gwhen} = $auth->{oauth_when} + ($role->{duration}||0);
    $ARGS->{_gduration} = $role->{duration};
  } elsif ($who ne $self->{PUBROLE}) {
    return $self->send_status_page(404);
  }
 
  $ARGS->{_gtime} ||= $r->can('request_time') ? $r->request_time : time();

  $self->warn("{Controller}[Group]{start}1");
  # not admin, or not in grousp, is alway rejected
  if ($ARGS->{_gadmin}) {
    return $self->send_status_page(401) if $ARGS->{_gshadow};
  } elsif ($actionHash->{groups} and (
	grep {$who eq $_} @{$actionHash->{groups}})
	) {
    return $self->send_status_page(401) if ($ARGS->{_gshadow} && $actionHash->{no_shadows} && grep {$who eq $_} @{$actionHash->{no_shadows}});
  } else {
    return $self->send_status_page(401);
  }
  $self->warn("{Controller}[Group]{end}1");

  if ($actionHash->{upload}) {
    $self->warn("{Controller}[Upload]{start}1");
# uploads => {html_field => [args_field, upload_dir]}
# in GO, html_field=args_field
    while (my ($field, $value) = each %{$actionHash->{upload}}) {
      my $field_new = shift @$value;
      my $dir = $self->{UPLOADDIR};
      $dir = shift(@$value) if $value;
      $ARGS->{$field_new} = ($value) ? Genelet::Utils::upload_field($r, $field, $dir, @$value) : Genelet::Utils::upload_field($r, $field, $dir);
      #unless ($ARGS->{$field_new}) {
      #  $self->warn("{Controller}[Upload]{end}1:$field");
	  #  return $self->error_page($filter, $ARGS, [1045, $field]);
      #}
    }
    $self->warn("{Controller}[Upload]{end}1");
  }

  $filter->args($ARGS);

  my $error;
  my $extra = {};
  # this is the 4 element array
  my $fk = $filter->fks()->{$who} if (!$ARGS->{_gadmin} && $filter->fks());
  if ($fk) {
    $self->warn("{Controller}[FKin]{start}1");
    $error = $self->assign_fk($who, $ARGS, $fk, $ARGS->{_gwhen}, $ARGS->{_gduration}, $extra);
    $self->warn("{Controller}[FKin]{end}1:$error");
    return $self->error_page($filter, $ARGS, $error) if $error;
  }

  my ($file, @property);
  if ($cache) {
    #$cache->current([$obj, $who, $action]);
    $cache->current([$who, $obj, $action]);
    ($file, @property) = $cache->cache_file($ARGS);
    if (@property) {
      $self->warn("{Controller}[Name]{cachecase}$file");
      if (my $output = $cache->read($file)) {
        $self->warn("{Controller}[Cache]{sending}1");
        return $self->send_page($output, $file, @property);
      }
    }
  }

  $self->warn("{Controller}[Preset]{start}1");
  $error = $filter->preset();
  $self->warn("{Controller}[Preset]{end}1:",$error);
  if ($error) {
    if ($error eq '200') {
      return $self->send_page($ARGS->{_goutput}) if $ARGS->{_goutput};
      $error = undef;
      goto STARTVIEW;
    } else {
      return $self->error_page($filter, $ARGS, $error);
    }
  }
  $self->warn("{Controller}[Validate]{start}1");
  $error = $filter->validate($action) and return $self->error_page($filter, $ARGS, [1035, $error]);
  $self->warn("{Controller}[Validate]{end}1");

  my ($dbh, $form);
  unless ($actionHash->{"options"} and grep {$_ eq "no_db"} @{$actionHash->{"options"}}) {
    $self->warn("{Controller}[DB]{start}1");
    return $self->error_page($filter, $ARGS, 1072) unless ($self->{DB} && (ref($self->{DB}) eq 'ARRAY'));
    my $db;
    if (ref($self->{DB}->[0]) eq 'ARRAY') {
      my $n = scalar @{$self->{DB}};
      if ($n==1) {
        $db = $self->{DB}->[0];
      } else {
        my $master = shift @{$self->{DB}};
        my $slave  = $self->{DB}->[int(rand() * ($n-1))];
        if ($actionHash->{master}) {
          $db = $master;
        } elsif ($actionHash->{slave}) {
          $db = $slave;
        } else {
          $db = (grep {$action eq $_} qw(topics edit)) ? $slave : $master;
        }
      }
    } else {
      $db = $self->{DB};
    }
    $dbh = DBI->connect(@$db) or return $self->error_page($filter, $ARGS, 1072);
    $self->warn("{Controller}[DB]{end}1");
    $self->dbh_trace($dbh);
  }

  $self->warn("{Controller}[Model]{start}1");
  $form = $model->new(dbh=>$dbh, args=>$ARGS, logger=>$self->{LOGGER}, storage=>$self->{STORAGE});
  if ($form) {
    $self->warn("{Controller}[Model]{end}1");
    my $ref = $self->{STORAGE}->{$save};
    for my $att (qw(nextpages current_table current_tables current_key current_id_auto key_in fields empties total_force sortby sortreverse pageno rowcount totalno maxpageno edit_pars update_pars insupd_pars insert_pars topics_pars)) {
      $form->$att(ref($ref->{$att}) ? dclone($ref->{$att}) : $ref->{$att}) if exists($ref->{$att});
    }
    unless ($actionHash->{"options"} and grep {$_ eq "no_db"} @{$actionHash->{"options"}}) {
      $error = $form->do_sql("SET NAMES 'utf8'") if $self->{DB}->[0] =~ /mysql/i;
      if ($error) {
        $dbh->disconnect;
        return $self->error_page($filter, $ARGS, $error);
      }
    }
  } else {
    return $self->send_status_page(404);
  }

  my $nextextras = [];
  $self->warn("{Controller}[Before]{start}1");
  $error = $filter->before($form, $extra, $nextextras);
  $self->warn("{Controller}[Before]{end}1:",$error);
  if ($error) {
    $dbh->disconnect if $dbh;
    if ($error eq '200') {
      return $self->send_page($ARGS->{_goutput}) if $ARGS->{_goutput};
      $error = undef;
      goto STARTVIEW;
    } else {
      return $self->error_page($filter, $ARGS, $error);
    }
  }

  unless ($actionHash->{"options"} and grep {$_ eq "no_method"} @{$actionHash->{"options"}}) {
    $self->warn("{Controller}[Action]{start}1");
    $error = $form->can($action) ? $form->$action($extra, @$nextextras) : 1051;
    $self->warn("{Controller}[Action]{end}1:",$error);
    if ($error) {
      $dbh->disconnect if $dbh;
      return $self->error_page($filter, $ARGS, $error);
    }
  }

  my $lists = $form->lists();
  # 1) don't asign any fk_tobe to admin role
  # 2) secret is not there or fk_tobe is not defined
  # 3) if the key to be is the role id, not assign anything
  if ($fk && $self->{SECRET} && $fk->[2] && $fk->[3] && ($fk->[2] ne $ARGS->{_gidname})) {
    $self->warn("{Controller}[FKout]{start}1");
    $self->assign_fk_tobe($lists, $fk, $ARGS->{_gwhen}, $who, $ARGS->{$ARGS->{_gidname}}, $escs);

    $self->warn("{Controller}[FKout]{end}1");
  } elsif ($escs) {
    for my $item (@$lists) {
      for (@$escs) {
        $item->{$_."_esc"} = uri_escape_utf8($item->{$_}) if defined($item->{$_});
      }
    }
  }

  $self->warn("{Controller}[After]{start}1");
  $error = $filter->after($form);
  $self->warn("{Controller}[After]{end}1:",$error);
  $dbh->disconnect if defined($dbh);

  if ($error) {
    undef $form;
    if ($error eq '200') {
      return $self->send_page($ARGS->{_goutput}) if $ARGS->{_goutput};
      $error = undef;
      goto STARTVIEW;
    } else {
      return $self->error_page($filter, $ARGS, $error);
    }
  }
 
  my $other = $form->other();

  $error = $filter->send_blocks($lists, $other);
  if ($self->{STOP_IF_BLOCKS}) {
    return $self->error_page($filter, $ARGS, $error) if $error;
  } else {
    $error = undef;
  }

  STARTVIEW:

  $self->warn("{Controller}[View]{start}1");
  my $output = '';
  if ($tag eq 'jsonp') {
    if ($output = $self->_json_data(\%hash, $action, $actionHash->{hide_json}, $ARGS, $lists, $other)) {
      $output =~ s/\n//g;
      $output = $ARGS->{$self->{CALLBACK_NAME}}.'('.$output.')';
    } else {
      $error = 'error in encode json: '.$@;
    }
  } elsif ($tag eq 'json') {
    unless ($output = $self->_json_data(\%hash, $action, $actionHash->{hide_json}, $ARGS, $lists, $other)) {
      $error = 'error in encode json: '.$@ unless $output;
    }
    $r->{headers_out}->{'Access-Control-Allow-Origin'} = $self->get_origin();
    $r->{headers_out}->{"Access-Control-Allow-Credentials"} = 'true';
  } elsif ($tag eq 'xml') {
    $output = $self->_xml_data(\%hash, $action, $ARGS, $lists, $other);
  } elsif ($tag eq 'form') {
    for my $key (@{$ARGS->{_gfield}}) {
      $output .= '&'.$key."=".uri_escape_utf8($ARGS->{$key});
    }
    substr($output,0,1) = '' if $output;
  } else {
    $error = $filter->get_template(\$output, $lists, $other, $action.".".$tag);
  }
  $self->warn("{Controller}[View]{end}1:",$error);
  undef $form;
  return $self->error_page($filter, $ARGS, $error) if $error;

  if ($file) {
    $self->warn("{Controller}[Cache]{start}1");
    $self->warn("{Controller}[Name]{cachecase}",$file);
    if ($cache->write($file, $output)) {
      $self->warn("{Controller}[Cache]{end}1:");
      $self->warn("{Controller}[OK]{sending}1");
      return $self->send_page($output, $file);
    } else {
      $self->warn("{Controller}[Cache]{end}1:write ",$file);
    }
  } elsif ($cache) {
    my ($files, $fails) =  $cache->destroy($ARGS);
    if ($files || $fails) {
      $self->warn("{Controller}[Cache]{start}1");
      $self->warn("{Controller}[Name]{cachecase}expire");
      $self->warn("{Controller}[Cache]{delete}",$files);
      $self->warn("{Controller}[Cache]{nodelete}",$fails);
      $self->warn("{Controller}[Cache]{end}1:");
    }
  }

  $self->warn("{Controller}[OK]{responding}1");
  return $self->send_page($output);
}
 
sub error_page {
  my $self = shift;
  my ($filter, $ARGS, $error) = @_;

  if (ref($error) eq 'HASH') {
    $ARGS->{error}    = "SYSTEM";
    $ARGS->{errorstr} = Dumper($error);
  } elsif (ref($error) eq 'ARRAY') {
    my $newcode = shift @$error;
    $ARGS->{error}    = $newcode;
    $ARGS->{errorstr} = $self->error_str($newcode) . join(" ", @$error);
  } else {
    return $self->send_status_page($error) if ($error =~ /^\d+$/ && $error < 1000);
    if ($error =~ /^\d+$/) {
      $ARGS->{error}    = $error;
      $ARGS->{errorstr} = $self->error_str($error);
    } else {
      $ARGS->{errorstr} = $error;
    }
  }

  my $output = '';
  my $e;
  if ($ARGS->{_gview} eq 'jsonp') {
    if ($output = $self->_json_error($ARGS->{error}, $ARGS->{errorstr})) {
      $output =~ s/\n//g;
      $output = $ARGS->{$self->{CALLBACK_NAME}}.'('.$output.')';
    } else {
      $e = $@;
    }
  } elsif ($ARGS->{_gview} eq 'json') {
    unless ($output = $self->_json_error($ARGS->{error}, $ARGS->{errorstr})) {
      $e = $@;
    }
    $self->{R}->{headers_out}->{'Access-Control-Allow-Origin'} = '*';
  } elsif ($ARGS->{_gview} eq 'xml') {
    $output = '<?xml version="1.0" encoding="UTF-8"?>'."\n<data>
<error>".$ARGS->{error}."</error>
<errorstr>".$ARGS->{errorstr}."</errorstr>
</data>\n";
  } elsif ($ARGS->{_gview} eq 'form') {
    return $self->send_status_page(401);
  } else {
    $e = $filter->get_errorpage(\$output);
  }

  return $self->send_nocache($e ? "Template error: ".Dumper($e).". Original error: ".$ARGS->{error}.": ".$ARGS->{errorstr} : $output);
}

sub _json_data {
  my $self = shift;
  my ($hash, $action, $hide_json, $ARGS, $lists, $other) = @_;

  $hash->{data} = $lists if $lists;
  while (my ($k, $v) = each %$ARGS) {
    next if (($hide_json and grep {$k eq $_} @$hide_json)
		or (substr($k,0,2) eq '_g') or ($k eq 'g_document'));
    if (substr($k,0,2) eq 'g_') {
      my $short = $k;
      substr($short,0,2) = '';
      $hash->{included}->{$short} = $v;
    } else {
      $hash->{incoming}->{$k} = $v;
    }
  }
  if ($other) {
    $hash->{relationships}->{$_} = $other->{$_} for (keys %$other);
  }

  my $output;
  if ($self->{JSON_LIB}) {
    my $true = 1;
    $hash->{success} = \$true;
    eval { 
      $output = to_json($hash);
    };
    return if $@;
  } else {
    $hash->{success} = 1;
    $Data::Dumper::Pair = " : ";
    $output = Dumper($hash);
    $output =~ s/=>/\:/g; 
    $Data::Dumper::Pair = " => ";
  }
  
  return $output;
}

sub _xml_data {
  my $self = shift;
  my ($hash, $action, $ARGS, $lists, $other) = @_;

  $hash->{$action} = $lists if $lists;
  while (my ($k, $v) = each %$ARGS) {
    next if (substr($k,0,2) eq '_g');
    $hash->{$k} = $v;
  }
  if ($other) {
    $hash->{$_} = $other->{$_} for (keys %$other);
  }

  my $str = '<?xml version="1.0" encoding="UTF-8"?>'."\n<data>\n";
  $str .= xml($hash);
  $str .= "</data>\n";
  return $str;

  sub xml_esc {
    my $value = shift or return;

    $value =~ s/&/&amp;/g;
    $value =~ s/"/&quot;/g;
    $value =~ s/'/&apos;/g;
    $value =~ s/</&lt;/g;
    $value =~ s/>/&gt;/g;

    return $value;
  }

  sub xml {
    my $hash = shift;
    my $str = "";

    while (my ($key, $value) = each %$hash) {
      if (ref($value) eq 'HASH') {
        $str .= "<$key>\n";
        $str .= xml($value);
        $str .= "</$key>\n";
      } elsif (ref($value) eq 'ARRAY') {
        for my $item (@$value) {
          $str .= "<$key>\n";
          $str .= xml($item);
          $str .= "</$key>\n";
        }
      } else {
        $str .= "<$key>".xml_esc($value)."</$key>\n";
      }
    }

    return $str;
  }
}

sub _json_error {
  my $self = shift;
  my ($error, $errorstr) = @_;

  my $output;
  if ($self->{JSON_LIB}) {
    my $false = 0;
    eval {
      $output = to_json({error=>$error, success=>\$false, errorstr=>($errorstr||'')});
    };
    return if $@;
  } else {
    $Data::Dumper::Pair = " : ";
    $output = Dumper({error=>$error, success=>0, errorstr=>$errorstr});
    $Data::Dumper::Pair = " => ";
  }

  return $output;
}

1;
