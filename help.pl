#!/usr/bin/perl

use strict;
use Data::Dumper;
use Getopt::Long;
use Cwd;
use DBI;

use Genelet::Helper::Base;
use Genelet::Helper::Table;
use Genelet::Helper::Angular;

my $force   = "";
my $angular = "";
my $dir     = $ENV{HOME}."/geneperl";
my $dbuser  = "";
my $dbpass  = "";
my $dbname  = "";
my $dbtype  = "mysql";
my $project = "myproject";
my $script  = "myscript";

my $usage = sub {
	return "Usage: $0 [options] table1 table2 ...
	--dir    program root, default '\$HOME/geneletperl'
	--dbtype  database type 'sqlite' or 'mysql', default 'mysql'
	--dbname  database name, mandatory
	--dbuser  database username, default ''
	--dbpass  database password, default ''
	--project project name, default to 'myproject'
	--script  script name, default to 'myscript'
	--force   if to override existing files, default to false
	--angular if to include Angular 1.3 files, default to false
"
};

GetOptions(
	"dir=s"      => \$dir,
	"dbuser=s"   => \$dbuser,
	"dbpass=s"   => \$dbpass,
	"dbname=s"   => \$dbname,
	"dbtype=s"   => \$dbtype,
	"project=s"  => \$project,
	"script=s"   => \$script,
	"angular!"   => \$angular,
	"force!"     => \$force) or die($usage->());

my @tables = @ARGV;
die $usage->() if @tables < 1;
die $usage->() if (!$dbname);

my $dbh = DBI->connect("dbi:".($dbtype eq "sqlite" ? "SQLite" : "MySQL").":$dbname", $dbuser, $dbpass) || die $!;

my $account = $tables[0];
my $base = Genelet::Helper::Base->new(
	root   => $dir,
	oriperl=> cwd(),
	force  => $force,
	dbh    => $dbh,
	dbtype => $dbtype,
	project=> $project,
	script => $script,
	account=> $account,
	tables => \@tables
);

my $extra = Genelet::Helper::Angular->new(
	root   => $dir,
	force  => $force,
	dbh    => $dbh,
	dbtype => $dbtype,
	project=> $project,
	script => $script,
	account=> $account,
	tables => \@tables
) if $angular;

my @arr = split "/", $script, -1;
my $script_last = pop @arr;
chdir $dir;
my $err = $base->dir_all()
	|| $base->write_it("conf/config.json", $base->config($dbname, $dbuser, $dbpass))
	|| $base->write_it("bin/$script_last", $base->script())
	|| $base->write_it("logs/debug.log", "")
	|| $base->write_it("lib/".ucfirst(lc $project)."/Model.pm", $base->project_model())
	|| $base->write_it("lib/".ucfirst(lc $project)."/Filter.pm", $base->project_filter())
	|| $base->write_it("views/admin/login.html", $base->login())
	|| $base->write_it("views/admin/error.html", $base->error())
	|| $base->write_it("views/public/error.html", $base->error());
die $err if $err;
my $mode = 0755;
chmod $mode, "bin/$script_last";
$mode = 0777;
chmod $mode, "logs/debug.log";

if ($angular) {
	$err = $extra->dir_angular()
	|| $base->write_it("www/index.html", $extra->index())
	|| $base->write_it("www/init.js", $extra->init())
	|| $base->write_it("www/admin/login.html", $extra->login())
	|| $base->write_it("www/admin/header.html", $extra->header())
	|| $base->write_it("www/admin/footer.html", "")
	|| $base->write_it("www/public/header.html", $extra->public())
	|| $base->write_it("www/public/footer.html", "");
	die $err if $err;
}

my $i=0;
for my $t (@tables) {
	my ($pk, $ak, $nons, $fields) = $base->get_table($t);
	die $nons unless $fields;
	my $table = Genelet::Helper::Table->new(
		root   => $dir,
		project=> $project,
		script => $script,
		account=> $account,
		tables => \@tables,
		table  => $t,
		pk     => $pk,
		ak     => $ak,
		nons   => $nons,
		fields => $fields
	);
	$table->set_objcls();
	my $angle = Genelet::Helper::Angular->new(
		root   => $dir,
		project=> $project,
		script => $script,
		account=> $account,
		tables => \@tables,
		table  => $t,
		pk     => $pk,
		ak     => $ak,
		nons   => $nons,
		fields => $fields
	);
	$angle->set_objcls();
	my $obj = $table->obj();	
	my $cls = $table->cls();	

	if ($i==0) {
		$err = $base->write_it("views/public/$obj/startnew.html", $base->top().$base->public()."\n</body></html>\n");
		die $err if $err;
	}

	my $lib = "lib/".ucfirst(lc $project)."/$cls";
	$err = $base->write_it("$lib/Model.pm", $table->model())
	|| $base->write_it("$lib/Filter.pm", $table->filter())
	|| $base->write_it("views/admin/$obj/startnew.html", $table->startnew())
	|| $base->write_it("views/admin/$obj/topics.html", $table->topics())
	|| $base->write_it("views/admin/$obj/dashboard.html", $table->topics())
	|| $base->write_it("views/admin/$obj/edit.html", $table->edit())
	|| $base->write_it("views/admin/$obj/insert.html", $base->top()."inserted\n"."</body>\n</html>\n")
	|| $base->write_it("views/admin/$obj/update.html", $base->top()."updated\n"."</body>\n</html>\n")
	|| $base->write_it("views/admin/$obj/delete.html", $base->top()."deleted\n"."</body>\n</html>\n");
	die $err if $err;

	if ($angular) {
		if ($i==0) {
			$err = $base->write_it("www/public/$obj/startnew.html", $base->top().$base->public()."\n</body></html>\n");
			die $err if $err;
		}
		$err = $base->write_it("www/admin/$obj/startnew.html", $angle->startnew())
		|| $base->write_it("www/admin/$obj/topics.html", $angle->topics())
		|| $base->write_it("www/admin/$obj/dashboard.html", $angle->topics())
		|| $base->write_it("www/admin/$obj/edit.html", $angle->edit());
		die $err if $err;
	}
	$i++;
}

$dbh->disconnect;

exit(0);
