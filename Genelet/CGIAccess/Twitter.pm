package Genelet::CGIAccess::Twitter;

use strict;
use Genelet::CGI;
use Genelet::Template;
use Genelet::Access::Social::Twitter;

use vars qw(@ISA);
@ISA = qw(Genelet::CGI Genelet::Template Genelet::Access::Social::Twitter);

1;
