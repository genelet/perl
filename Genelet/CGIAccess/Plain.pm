package Genelet::CGIAccess::Plain;

use strict;

use Genelet::CGI;
use Genelet::Template;
use Genelet::Access::Ticket;

use vars qw(@ISA);
@ISA = qw(Genelet::CGI Genelet::Template Genelet::Access::Ticket);

1;
