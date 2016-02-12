package Log::Log4perl::Level;
# This is a mock for this module so calls to its methods
# do nothing.

use Exporter qw(import);
use vars qw($INFO $DEBUG $TRACE $WARN $ERROR $FATAL);
our @EXPORT_OK = qw($INFO $DEBUG $TRACE $WARN $ERROR $FATAL);

our( $INFO, $DEBUG, $TRACE, $WARN, $ERROR, $FATAL ) =
	qw(INFO DEBUG TRACE WARN ERROR FATAL);

sub AUTOLOAD { __PACKAGE__ }

__PACKAGE__;
