# perl
Perl Version of the Genelet Web Development Framework at http://www.genelet.com

The Perl version of Genelet is nothing more than a collection of well-thought CGI/FCGI packages to develop large-scale web project in a convenience, fast and organized way. While you are still be able to do everything in your own style, the packages are aimed nevertheless to be the most efficient and elegant solutions.

Genelet is in Object-Oriented Perl which follows strict MVC pattern and provides full REST API access. Popular services like OAuth login, SMS and mobile push notifications are built-in and ready to use. It has also a debugging tool to help you fix bugs. As an add-on, we have a bridge Javascript file for you to develop one-page website using Angular 1.3 web framework.

While Genelet is as powerful as, if not more powerful than, other frameworks, it is definitely a lot easier to learn and takes much shorter development circle to finish web project.

Genelet has little dependence on 3rd party packages. The list is so short that we can list them explicitly here: JSON (for JSON), XML::LibXML (for XML), DBI (for database), LWP::UserAgent (for OAuth etc.), URI and URI::Escape (for URL manipulation), Digest::HMAC_SHA1 and MIME::Base64 (for security), Net::SMTP (for email), Template (for HTML5 templates), and Test::More (for unit testing). The minimal Perl version it works with is 8.10.

Virtual Hosting

Genelet is always able to run in the CGI mode. If you have a root access to the server, you can configure it to run in the Fast CGI model using Apache’s mod_fcgid. Note that many virtual host serices run PHP under Apache’s mod_fcgid, so you may run Genelet with the PHP speed in a virtual hosting too.  You can develop in CGI, which also provides a better debugging envionment, and switch to Fast CGI anytime to gain the PHP speed.

Developer Manual: http://www.genelet.com/index.php/2017/02/08/perl-development-manual/

Tutorial: http://www.genelet.com/index.php/tutorial-perl/
