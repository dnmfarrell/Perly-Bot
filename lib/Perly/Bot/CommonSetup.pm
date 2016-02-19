use v5.22;

use feature qw(signatures postderef);
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
