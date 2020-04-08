package Genelet::CGIAccess::Github;

use strict;
use Genelet::CGI;
use Genelet::Template;
use Genelet::Access::Social::Github;

use vars qw(@ISA);
@ISA = qw(Genelet::CGI Genelet::Template Genelet::Access::Social::Github);

1;
