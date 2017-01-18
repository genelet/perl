package Genelet::CGIAccess::Facebook;

use strict;
use Genelet::CGI;
use Genelet::Template;
use Genelet::Access::Social::Facebook;

use vars qw(@ISA);
@ISA = qw(Genelet::CGI Genelet::Template Genelet::Access::Social::Facebook);

1;
