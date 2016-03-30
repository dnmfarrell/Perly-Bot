use v5.22;


=pod

I mean for this module to have all the stupid stuff we'd want to be at
the top of a file, and to have it import everything into the module that
used it like Modern::Perl does.

Somehow it's not all working out.

=cut

use strict;
use warnings;
use feature qw(:5.22 signatures);
no warnings qw(experimental::signatures);

use Data::Dumper;
use File::Spec::Functions;
use Log::Log4perl;
use Path::Tiny;

use Perly::Bot::Config;
use Perly::Bot::Post;
use Perly::Bot::UserAgent;

# we should load this from somewhere else
use Perly::Bot::BlogsPerlOrg;

sub import ( $self ) {
	feature->import( qw(signatures postderef) );
	warnings->import;
	warnings->unimport( qw(experimental::signatures experimental::postderef) );
	File::Spec::Functions->import;
	Carp->import( qw(carp croak) );
	Data::Dumper->import;
	}

1;
