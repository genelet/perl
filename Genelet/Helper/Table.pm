package Genelet::Helper::Table;

use strict;
use Data::Dumper;
use Genelet::Helper::Base;

use vars qw(@ISA);
@ISA = qw(Genelet::Helper::Base);

__PACKAGE__->setup_accessors(
	table=> "",
	obj => "",
	cls => "",
	pk   => "",
	ak   => "",
	nons => [],
	fields=>[],
);

sub set_objcls {
	my $self = shift;

	($self->{OBJ}, $self->{CLS}) = $self->_objcls($self->{TABLE});

	return;
}

sub component {
  my $self = shift;

  my $groups  = ($self->{TABLE} eq $self->{ACCOUNT}) ? '"groups":["public"],' : '';

  my $adds = '"'.join('","', @{$self->{FIELDS}}).'"';
  my $edit = $adds;
  $edit .= ',"'.$self->{AK}.'"' if $self->{AK};
  my $str = qq`{
	"actions" : {
		"topics"  :{},
		"startnew":{$groups"options":["no_method", "no_db"]},
		"insert"  :{"validate":["`.join('","', @{$self->{NONS}}).qq`"]},
		"delete"  :{"validate":["`.$self->{PK}.qq`"]},
		"edit"    :{"validate":["`.$self->{PK}.qq`"]},
		"update"  :{"validate":["`.$self->{PK}.qq`"]}
	},
	"current_table"   :"`.$self->{TABLE}.qq`",
	"current_key"     :"`.$self->{PK}.qq`",
	"insert_pars"     :[$adds],
	"update_pars"     :[$edit],
	"topics_pars"     :[$edit],
	"edit_pars"       :[$edit]`;
	if ($self->{AK}) {
		$str .= qq`,
	"current_id_auto" :"`.$self->{AK}.qq`"`;
	}
	return $str."\n}";
}

sub model {
	my $self = shift;
	my $PROJECT  = ucfirst(lc $self->{PROJECT});
	my $CLS      = $self->{CLS};

	return qq`package $PROJECT`.qq`::$CLS`.qq`::Model;

use strict;
use $PROJECT`.qq`::Model;
use vars qw(\$AUTOLOAD \@ISA);

\@ISA=('$PROJECT`.qq`::Model');

1;
`;
}

sub filter {
	my $self = shift;
	my $PROJECT = ucfirst(lc $self->{PROJECT});
	my $CLS     = $self->{CLS};
	return qq`package $PROJECT`.qq`::$CLS`.qq`::Filter;

use strict;
use $PROJECT`.qq`::Filter;
use vars qw(\@ISA);

\@ISA=('$PROJECT`.qq`::Filter');

sub preset {
#	my \$self = shift;
#	my \$err  = \$self->SUPER::preset(\@_);
#	return \$err if \$err;

#	my \$ARGS   = \$self->{ARGS};
#	my \$r      = \$self->{R};
#	my \$who    = \$ARGS->{g_role};
#	my \$action = \$ARGS->{g_action};

	return;
}

sub before {
#	my \$self = shift;
#	my \$err  = \$self->SUPER::before(\@_);
#	return \$err if \$err;

#	my \$ARGS   = \$self->{ARGS};
#	my \$r      = \$self->{R};
#	my \$who    = \$ARGS->{g_role};
#	my \$action = \$ARGS->{g_action};

	return;
}

sub after {
#	my \$self = shift;
#	my \$err  = \$self->SUPER::after(\@_);
#	return \$err if \$err;

#	my \$ARGS   = \$self->{ARGS};
#	my \$r      = \$self->{R};
#	my \$who    = \$ARGS->{g_role};
#	my \$action = \$ARGS->{g_action};

#	my (\$form, \$lists) = \@_;

	return;
}

1;
`;
}

my $nice = sub {
	my $name = shift;
	my @arr;
	push(@arr, ucfirst(lc($_))) for (split("_", $name));
	return join(" ", @arr);
};

sub titles {
	my $self = shift;
	
	my $n = 0;
	for my $name (@{$self->{FIELDS}}) {
		if (length($name)>$n) {
			$n = length($name);
		}
	}
	my $ts;
	for my $name (@{$self->{FIELDS}}) {
		my $i = $n - length($name);
		$ts->{$name} = (' ' x $i) . $nice->($name);
	}

	return $ts;
}

sub startnew {
	my $self = shift;
	my $obj = $self->{OBJ};

	my $str = qq`<h3>Create New</h3>
<form method=post action="$obj">
<input type=hidden name=action value="insert" />
<pre>
`;
	my $ts = $self->titles();
	while (my ($val, $title) = each %$ts) {
		$str .= $title.qq`: <input type=text name="$val" />
`;
	}
	$str .= qq`</pre>
<input type=submit value=" Submit " />
</form>
`;
	return $self->top().$str.qq`\n</body>\n</html>\n`;
}

sub edit {
	my $self = shift;
	my $obj = $self->{OBJ};

	my $str = qq`<h3>Update Record</h3>
<form method=post action="$obj">
<input type=hidden name=action value="update" />
<input type=hidden name=`.$self->{PK}.qq` value="[% `.$self->{PK}.qq` %]" />
<pre>[% SET item=edit.0 %]
`;
	my $ts = $self->titles();
	while (my ($val, $title) = each %$ts) {
		$str .= $title.qq`: <input type=text name="$val" value="[% item.$val %]" />
`
	}
	$str .= qq`</pre>
<input type=submit value=" Submit " />
</form>
`;
	return $self->top().qq`\n<h4>Welcome <em>[% login %]</em>! You are role <em>[% g_role %]</em>.  <a href="[% g_json_url %]">JSON View</a> <a href="logout">LOGOUT</a></h4>$str\n</body>\n</html>\n`;
}

sub topics {
	my $self = shift;
	my $pk = $self->{PK};
	my $obj = $self->{OBJ};

	my @fields = @{$self->{FIELDS}};
	unshift(@fields, $pk) if ($pk eq $self->{AK});

	my $str = qq`<h3>List of Records</h3>
<table>
<thead>
<tr>
`;
	for my $val (@fields) {
		$str .= qq`<th>`.$nice->($val).qq`</th>
`;
	}
	$str .= qq`</tr>
</thead>
<tbody>[% FOREACH item IN topics %]
<tr>
`;
	for my $val (@fields) {
		$str .= ($pk eq $val )?
qq`<td><a href="$obj?action=edit&$pk=[% item.$pk %]">[% item.$pk %]</a></td>
` :
qq`<td>[% item.$val %]</td>
`;
	}
	$str .= qq`<td><a href="$obj?action=delete&$pk=[% item.$pk %]">DEL</a></td>
</tr>
[% END %]</tbody>
</table>
<h3><a href="$obj?action=startnew">Create New</a></h3>
`;

	return $self->top().qq`\n<h4>Welcome <em>[% login %]</em>! You are role <em>[% g_role %]</em>.  <a href="[% g_json_url %]">JSON View</a> <a href="logout">LOGOUT</a></h4>$str\n</body>\n</html>\n`;
}

1;
