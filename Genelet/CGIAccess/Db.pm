package Genelet::CGIAccess::Db;

use strict;

use Genelet::CGI;
use Genelet::Template;
use Genelet::Access::DBI;

use vars qw(@ISA);
@ISA = qw(Genelet::CGI Genelet::Template Genelet::Access::DBI);

1;
