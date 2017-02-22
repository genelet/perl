package Genelet::Helper::Base;

use strict;
use DBI;
use Genelet::Accessor;

use vars qw(@ISA);
@ISA = qw(Genelet::Accessor);

__PACKAGE__->setup_accessors(
	force  => undef,
	dbtype => "",
	dbh    => {},
	project=> "myproject",	
	script => "myscript",	
	root   => "",
	oriperl => "",
	account=> "",
	tables => []
);

sub get_table {
	my $self = shift;
	if ($self->{DBTYPE} eq "sqlite") {
		return $self->_sqlite(@_);
	}
	return $self->_mysql(@_);
}

sub _sqlite {
	my $self = shift;
	my $table = shift;

#Rowid Field Type Notnull Default PK
	my $sth = $self->{DBH}->prepare("PRAGMA table_info($table)");
	$sth->execute();
	my $lists = $sth->fetchall_arrayref();

	my $pk;
	my $ak;
	my (@nons, @fields);
	
	for my $item (@$lists) {
		my ($Rowid, $Field, $Type, $Notnull, $Default, $Pri) = @$item;
		my $non = 0;
		if (uc($Default) eq "CURRENT_TIMESTAMP") {
			next;
		}
		if ((uc($Type) eq "INTEGER") and $Pri) {
			$ak = $Field;
			$pk = $Field;
			next;
		}
		if ($Pri) {
			$pk = $Field;
		}
		if ($Notnull) {
			push @nons, $Field;
		}
		push(@fields, $Field);
	}

	return $pk, $ak, \@nons, \@fields;
}

sub _mysql {
	my $self = shift;
	my $table = shift;

	my $lists = $self->{DBH}->selectall_hashref("DESC ".$table, ["Field", "Type", "Null", "Key", "Default", "Extra"]);	

	my $pk;
	my $ak;
	my (@nons, @k, @uk, @fields);
	
	while (my($field, $item) = each $lists) {
		if ($item->{"Default"} eq "CURRENT_TIMESTAMP") {
			next;
		}
		my $non = 0;
		if ($item->{"Extra"} eq "auto_increment") {
			$ak = $field;
			if ($item->{"Key"} eq "PRI") {
				$pk = $field;
			}
			next;
		}
		if ($item->{"Key"} eq "PRI") {
			$pk = $field;
		}
		if ($item->{"Key"} eq "UNI") {
			push(@uk, $field);
		} elsif ($item->{"Key"} eq "MUL") {
			push @k, $field;
		}
		if ($item->{"Null"} eq "NO" ) {
			push @nons, $field;
		}
		push(@fields, $field);
	}

	if ($pk and @uk) {
		$pk = $uk[0];
	}

	return $pk, $ak, \@nons, \@fields;
}

sub write_it {
	my $self = shift;
	my ($filename, $content) = @_;

	if ($self->{FORCE} || !(-e $filename)) {
		chdir $self->{ROOT};
		my @pathes = split "/", $filename, -1;
		my $real = pop @pathes;
		my $dir = join("/", @pathes);
		$dir ||= ".";
		chdir $dir;
		local *FH;
		open(*FH, ">", $real) || return $!.": ".$real." under $dir";
		print FH $content;
		close(FH);

		chdir $self->{ROOT};
	}
	return;
}

sub _dirs {
	my $self = shift;
	my @dirs = @_;

    for my $dir (@dirs) {
		if (-d $dir) {
			next;
		} elsif (-e $dir) {
			return "$dir exists but not a directory.";
		} else {
			return $! if (!(mkdir $dir));
		}
	}

	return;
}

sub _objcls {
    my $self = shift;
	my $name = shift;

    my @arr = split "_", $name, -1;
    my $OBJ = lc(join "", @arr);
	my $CLS = ucfirst($OBJ);
#   my $CLS = join "", map {ucfirst(lc $_)} @arr;

    return ($OBJ, $CLS);
}

sub dir_all {
	my $self = shift;

	my $root = $self->{ROOT};
	my $proj = ucfirst(lc $self->{PROJECT});

    my @dirs = ($root, $root."/lib", $root."/lib/".$proj, $root."/bin", $root."/conf", $root."/logs", $root."/www", $root."/views", $root."/views/admin", $root."/views/public");

	my $i=0;
    for my $v (@{$self->{TABLES}}) {
		my ($obj, $cls) = $self->_objcls($v);	
		push(@dirs, $root."/lib/".$proj."/$cls");
		push(@dirs, $root."/views/admin/".$obj);
		if ($i==0) {
			push(@dirs, $root."/views/public/".$obj);
		}
		$i++;
    }

	return $self->_dirs(@dirs);
}

sub config {
	my $self = shift;
	my ($name, $user, $pass) = @_;
	my $root = $self->{ROOT};

	return qq`{
	"Document_root" : "$root/www",
	"Project"  : "`.ucfirst($self->{PROJECT}).qq`",
	"Script"   : "`.$self->{SCRIPT}.qq`",
	"Template"      : "$root/views",
	"Pubrole"       : "public",
	"Secret"        :"sf09i51jlbnd0324e;fn 340913i5i13vtnsdkvn akUIUUIHKJHV",
	"Chartags"      : {
		"html" : {
			"Content_type":"text/html; charset='UTF-8'",
			"Short":"html"
		},
		"json" : {
			"Content_type":"application/json; charset='UTF-8'",
			"Short":"json",
			"Challenge":"challenge",
			"Logged":"logged",
			"Logout":"logout",
			"Failed":"failed",
			"Case":1
		}
	},

	"Log": {
		"filename": "$root/logs/debug.log",
		"minlevel": 0,
		"maxlevel": "info"
	},

	"Db" : ["dbi:`.(($self->{DBTYPE} eq 'sqlite')?'SQLite':'Mysql').qq`:$name", "$user", "$pass"],

	"Roles" : {
		"admin" : {
			"Id_name" : "login",
			"Is_admin" : true,
			"Attributes" : ["login","provider"],
			"Type_id" : 1,
			"Surface" : "cadmin",
			"Duration" : 86400,
			"Max_age"  : 86400,
			"Secret" : "13123ed%OINK()H%^*&(PIHNdsncxzdlgpwwq;akdsgfhgf f982",
			"Coding" : "(*&*(&(*)sfd fasf 14812 4HJKL BS1312fhdf fd0-41fdf f",
			"Logout" : "/",
			"Issuers" : {
				"plain" : {
					"Default" : true,
					"Credential" : ["login", "passwd", "direct", "cadmin"],
					"Provider_pars": {"Def_login":"hello", "Def_password":"world"}
				}
			}
		}
	}
}`;
}

sub script {
	my $self = shift;

	my @arr;
	for my $t (@{$self->{TABLES}}) {
		my ($obj, $cls) = $self->_objcls($t);
		push @arr, $cls;
	}
	my $comp = '"'.join('", "', @arr).'"';

	return qq`#!/usr/bin/perl

use lib qw(`.$self->{ROOT}.qq`/lib `.$self->{ORIPERL}.qq`);

use strict;
use JSON;

use DBI;
use XML::LibXML;
use LWP::UserAgent;

use File::Find;
use Data::Dumper;
use URI;
use URI::Escape();
use Digest::HMAC_SHA1;
use MIME::Base64();
use Template;

use Genelet::Dispatch;

Genelet::Dispatch::run("`.$self->{ROOT}.qq`/conf/config.json", [$comp]);

exit;
`;
}

sub project_filter {
	my $self = shift;

	return qq`package `.ucfirst(lc $self->{PROJECT}).qq`::Filter;

use strict;
use Genelet::Filter;
use Genelet::Template;

use vars qw(\@ISA);

\@ISA = qw(Genelet::Filter Genelet::Template);

1;
`;
}

sub project_model {
	my $self = shift;

	my $db = ($self->{DBTYPE} eq 'sqlite') ? "SQLite" : "Mysql";
	return qq`package `.ucfirst(lc $self->{PROJECT}).qq`::Model;

use strict;
use Genelet::Model;
use Genelet::$db;
use Genelet::Crud;

use vars qw(\@ISA);
\@ISA = qw(Genelet::Model Genelet::$db);

__PACKAGE__->setup_accessors(
	'empty_name' => 'empties',
	'sortby' => 'sortby',
	'totalno' => 'totalno',
	'rowcount' => 'rowcount',
	'pageno' => 'pageno',
	'max_pageno' => 'max_pageno',
	'total_force' => 1,
	'sortreverse' => 'sortreverse',
	'field' => 'field'
);

1;
`;
}

sub top {
    my $self = shift;

    return qq`<!doctype html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Administrative Pages</title>
</head>
<body>
<h2>`.ucfirst(lc $self->{PROJECT}).qq`</h2>
`;
}

sub public {
	my $self = shift;
	my ($obj, $cls) = $self->_objcls($self->{ACCOUNT});
	
	return qq`<h4><a href="`.$self->{SCRIPT}.qq`/admin/html/$obj?action=topics">Enter Admin (Server Side)</a></h4>
`;
}

sub login {
	my $self = shift;
	return qq`<!doctype html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Administrative Pages</title>
</head>
<body>
<h2>LOGIN</h2>
<FORM METHOD="POST">
<INPUT TYPE="HIDDEN" NAME="go_uri" VALUE="[% go_uri %]">
<div class="form_settings">
	<p><span class=fixed>Username</span>
		<INPUT class=contact TYPE="TEXT"  NAME="login" />
	</p><p><span class=fixed>Password</span>
		<INPUT class=contact TYPE="PASSWORD" NAME="passwd" />
	</p><p style="padding-top: 15px"><span class=fixed>&nbsp;</span>
		<INPUT class="submit" TYPE="SUBMIT" VALUE=" Sign In " />
	</p>
</div>
</FORM>
</body>
</html>
`;
}

sub error {
	my $self = shift;
	return qq`<!doctype html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Error Page</title>
</head>
<body>
<h2>Error Found</h2>
<h3>No. [% error %]: [% errorstr %]</h3>

</body>
</html>
`;
}

1;
