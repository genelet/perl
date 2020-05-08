package Genelet::CGIAccess::Zoom;

use strict;
use Genelet::CGI;
use Genelet::Template;
use Genelet::Access::Social::Zoom;

use vars qw(@ISA);
@ISA = qw(Genelet::CGI Genelet::Template Genelet::Access::Social::Zoom);

1;
