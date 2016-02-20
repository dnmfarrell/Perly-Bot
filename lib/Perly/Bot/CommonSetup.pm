use v5.22;


=pod

I mean for this module to have all the stupid stuff we'd want to be at
the top of a file, and to have it import everything into the module that
used it like Modern::Perl does.

Somehow it's not all working out.

=cut

use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);
use strict;
use warnings;

use File::Spec::Functions;
use Log::Log4perl;

use Perly::Bot::Config;
use Perly::Bot::Feed::Post;
use Perly::Bot::UserAgent;

sub import ( $self ) {
	feature->import( qw(signatures postderef) );
	warnings->import;
	warnings->unimport( qw(experimental::signatures experimental::postderef) );
	File::Spec::Functions->import;
	Carp->import( qw(carp croak) );
	}

1;
