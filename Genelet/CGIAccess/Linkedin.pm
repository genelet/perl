package Genelet::CGIAccess::Linkedin;

use strict;
use Genelet::CGI;
use Genelet::Template;
use Genelet::Access::Social::Linkedin;

use vars qw(@ISA);
@ISA = qw(Genelet::CGI Genelet::Template Genelet::Access::Social::Linkedin);

1;
