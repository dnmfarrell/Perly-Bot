use strict;
use warnings;
use v5.22;
use feature qw(postderef postderef_qq);
no warnings qw(experimental::postderef);

use Test::More 0.95;

use Data::Dumper;
use File::Spec::Functions;
use YAML::XS 'LoadFile';

my $class       = 'Perly::Bot::Config';
my $config_file = catfile( qw(t test_config.yml) );

subtest setup => sub {
	use_ok($class) or BAIL_OUT( "$class did not load" );
	};

subtest new => sub {
	my @args   = $config_file;
	my $config = new_ok( $class, \@args );
	can_ok( $config, '_config_setup' );
	ok( $config->_config_setup, "_config_setup returns true" );
	};

subtest get_config => sub {
	my @args   = $config_file;
	my $config = new_ok( $class, \@args );

	can_ok( $class, 'get_config' );
	my $config2 = $class->get_config;
	is( $config, $config2, "Objects from new and get_config are the same" );
	};

subtest media_objects => sub {
	ok( $class->_config_setup, "_config_setup returns true" );
	my $config = $class->get_config;
	isa_ok( $config, $class );

	can_ok( $config, 'get_media_classes' );

	my @classes = $config->get_media_classes;
	ok( @classes > 0, "There are some media classes" );
	diag( "Media classes are @classes" );

	my $method = 'has_media_object';
	can_ok( $config, $method );
	can_ok( $config, 'get_media_object' );
	foreach my $class ( @classes ) {
		ok( $config->has_media_object( $class ), "has_media_object for $class" );
		my $object = $config->get_media_object( $class );
		isa_ok( $object, $class );
		}




	};

subtest feeds => sub {
	my $method = 'feeds';
	can_ok( $class, $method );
	my $ref = $class->$method();
	is( ref $ref, ref [], "$method returns an array ref" );
	ok( $ref->@* > 0, "There are some items in the array" );
	diag( "Feeds are ", Dumper( $ref ) ) if $ENV{TEST_VERBOSE};
	foreach my $feed ( $ref->@* ) {
		isa_ok( $feed, 'Perly::Bot::Feed', "Feed for $feed->{url} is a feed class" );
		}
	};

done_testing();
