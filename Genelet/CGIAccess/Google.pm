package Genelet::CGIAccess::Google;

use strict;
use Genelet::CGI;
use Genelet::Template;
use Genelet::Access::Social::Google;

use vars qw(@ISA);
@ISA = qw(Genelet::CGI Genelet::Template Genelet::Access::Social::Google);

1;
