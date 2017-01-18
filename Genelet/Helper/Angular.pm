package Genelet::Helper::Angular;

use strict;
use Genelet::Helper::Table;

use vars qw(@ISA $AUTOLOAD);
@ISA = qw(Genelet::Helper::Table);

sub dir_angular {
    my $self = shift;

	my $root = $self->{ROOT};
	my @dirs = ($root."/www/admin", $root."/www/public");

	my $i=0;
	for my $v (@{$self->{TABLES}}) {
		my ($obj, $cls) = $self->_objcls($v);
		push(@dirs, $root."/www/admin/".$obj);
		if ($i==0) {
			push(@dirs, $root."/www/public/".$obj);
		}
		$i++;
	}

	return $self->_dirs(@dirs);
}

sub init {
	my $self = shift;
	my ($obj, $cls) = $self->_objcls($self->{ACCOUNT});

	return qq`var GOTO = {
    script    : "/`.$self->{SCRIPT}.qq`",
    app       : "`.$self->{PROJECT}.qq`_app",
    controller: "`.$self->{PROJECT}.qq`_controller",
    role      : "public",
    component : "$obj",
    action    : "startnew",

    html      : "html",
    json      : "json",
    header    : "header",
    footer    : "footer",
    login     : "login",
    "delete"  : "delete",
    insert    : "insert",
    update    : "update",
    lists     : "Lists",
    challenge : "challenge",
    failed    : "failed",
    logged    : "logged",
    logout    : "logout"
};`
}

sub index {
	my $self = shift;
	return qq`<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="fragment" content="!" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>` . ucfirst(lc $self->{PROJECT}) . qq`</title>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js"></script>
    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
    <script src="https://ajax.googleapis.com/ajax/libs/angularjs/1.3.15/angular.min.js"></script>
    <script src="init.js"></script>
    <script src="genelet.js"></script>
    <link href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body { padding-top: 50px; }
        .starter-template { padding: 40px 15px; text-align: center; }
        .nav, .pagination, .carousel, .panel-title a { cursor: pointer; }
    </style>
  </head>

  <body ng-app="`.$self->{PROJECT}.qq`_app" ng-controller="`.$self->{PROJECT}.qq`_controller">

    <ng-include src="partial_header"></ng-include>

    <div class="container">
    <ng-include src="partial"></ng-include>
    </div>

    <ng-include src="partial_footer"></ng-include>

  </body>
</html>
`;
}

sub login {
	my $self = shift;
	my ($obj, $cls) = $self->_objcls($self->{ACCOUNT});

	return qq`<h3>Error: {{ names.errorstr }}</h3>
<FORM name=login ng-init="data.direct=1" ng-submit="
\$parent.login('admin', 'plain', data, {action:'topics',component:'$obj',role:'admin'})">
<pre>
   LOGIN: <INPUT TYPE="TEXT"     ng-model="data.login" />
PASSWORD: <INPUT TYPE="PASSWORD" ng-model="data.passwd" />
<INPUT TYPE="SUBMIT" value=" SUBMIT " />
</pre>
</FORM>
`;
}

sub header {
	my $self = shift;
	my ($obj, $cls) = $self->_objcls($self->{ACCOUNT});

	my $str = qq`
    <div class="navbar navbar-inverse navbar-fixed-top" role="navigation">
      <div class="container">
        <div class="navbar-header">
          <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target=".navbar-collapse">
            <span class="sr-only">Toggle navigation</span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="" ng-click="\$parent.go('public', '$obj', 'startnew')">HOME</a>
        </div>
        <div class="collapse navbar-collapse">
          <ul class="nav navbar-nav">
`;
    for my $v (@{$self->{TABLES}}) {
		my ($obj, $cls) = $self->_objcls($v);
		$str .= qq`<li><a href="" ng-click="\$parent.go('admin', '$v','topics')">`.ucfirst(lc $v).qq`</a></li>`;
    }
	$str .= qq`        <li><a target="json" href="{{ names.ARGS._guri_json[0] }}" target=json>JSON</a></li>
            <li><a>Welcome <em>{{ names.ARGS.login[0] }}</em>! You are role <em>{{ names.ARGS._grole[0] }}</em>.</a></li>
            <li><a href="" ng-click="\$parent.go('admin','logout', '', {}, {role:'public',component:'$obj',action:'startnew'})">LOGOUT</a></li>
          </ul>
        </div>
      </div>
    </div>
`;

	return $str;
}

sub startnew {
	my $self = shift;
	my ($obj, $cls) = $self->_objcls($self->{ACCOUNT});
 
    my $str = qq`<h3>Create New</h3>
<form name=`.$self->{ACCOUNT}.qq`_startnew ng-submit="
\$parent.send('admin', '$obj', 'insert', single, {
    action:'topics'
})
"><pre>
`;
	my $ts = $self->titles();
	while (my ($val, $title) = each %$ts) {
        $str .= $title.qq`: <input type=text ng-model="single.`.$val.qq`" placeholder="`.$title.qq`" />
`;
    }
    $str .= qq`</pre>
<div>
    <button type=submit>Submit Now</button>
</div>

</form>
`;
	return $str;
}

sub edit {
	my $self = shift;

	my $str = qq`<h3>Update Record</h3>
<form name="`.$self->{TABLE}.qq`_edit" ng-submit="
\$parent.send('admin', '`.$self->{TABLE}.qq`', 'update', single, {
    action:'topics'
})
">
<pre>
`;
	my $ts = $self->titles();
	while (my ($val, $title) = each %$ts) {
        $str .= $title.qq`: <input type=text ng-model="single.`.$val.qq`" value="{{ single.`.$val.qq` }}" />
`;
    }
    $str .= qq`</pre>

<button type=submit> Update </button>
</form>
`;

    return $str;
}

sub topics {
	my $self = shift;

	my $table = $self->{TABLE};
	my $pk = $self->{PK};

    my $str = qq`<h3>List of Records</h3>
<table class="table table-striped table-condensed">
<thead>
<tr>
`;
    for my $val (@{$self->{FIELDS}}) {
        $str .= qq`<th>`.join(" ", ucfirst(lc(split(name, "_")))).qq`</th>
`;
    }

    $str .= qq`<td> </td></tr>
</thead>
<tbody>
<tr ng-repeat="item in names.Lists">
`;
	for my $val (@{$self->{FIELDS}}) {
		$str .= ($pk eq $val) ?
qq`<td><a href="" ng-click="
\$parent.go('admin', '$table', 'edit', {$pk: item.$pk}
)">{{ item.$pk }}</a></td>
` :
qq`<td>{{ item.$val }}</td>
`;
    }
    $str .= qq`<td><a href="" ng-click="
\$parent.go('admin', '$table', 'delete', {$pk: item.$pk},
{operator:'delete',id_name:'$pk'}
)">DEL</a></td>
</tr>
</tbody>
</table>

<a href="" ng-click="go('admin', '$table', 'startnew')">Create New Record</a>
`;
    return $str;
}

1;
