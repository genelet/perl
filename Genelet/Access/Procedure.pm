package Genelet::Access::Procedure;

use strict;

sub run_sql {
  my $self = shift;
  my ($call_name, $in_vals) = @_;

  my $out_pars = $self->{OUT_PARS} || $self->{ATTRIBUTES};
  my $out_hash = $self->{OUT_HASH};

  my ($str, $out_str);

  if ($call_name =~ /^select /i) {
    $str = $call_name;
  } else {
    my $n = scalar @$in_vals;
    $out_str = '@'.join(',@', @$out_pars);
    $str = 'CALL '.$call_name.'('.join(',', ("?")x$n).','.$out_str.')';
  }

  $self->warn("{Loginout}[DBI]{start}1");
  unless ($self->{DB}) {
    $self->warn("{Loginout}[DBI]{system}1:1033");
    return 1033;
  }

  my $dbh = DBI->connect(@{$self->{DB}}) or return $!;
  $self->dbh_trace($dbh);

  my ($sth, $ok);
  if ($out_str) {
    my $do = $dbh->prepare($str);
    $ok = $do->execute(@$in_vals);
    if ($ok) {
      $sth= $dbh->prepare("SELECT $out_str");
      $ok = $sth->execute();
    }
  } else {
    $sth = $dbh->prepare($str);
    $ok = $sth->execute(@$in_vals);
  }
  unless ($ok) {
    $dbh->disconnect;
    $self->warn("{Loginout}[DBI]{end}1:1032");
    return 1032;
  }

  @{$out_hash}{@$out_pars} = $sth->fetchrow();
  my $rows = $sth->rows;
  $sth->finish;
  $dbh->disconnect;
  if ($rows<1) {
    $self->warn("{Loginout}[DBI]{end}1:1031");
    return 1031;
  }

  $self->warn("{Loginout}[DBI]{end}1");
  return;
}

1;
