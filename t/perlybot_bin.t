use Test::More 0.98;

use File::Spec::Functions qw(catfile);

my $class = 'Perly::Bot::Bin';
my $path = catfile( qw( bin perlybot ) );

subtest compile => sub {
	ok( -e $path, "$path exists" ) or BAILOUT();
	ok( "$^X -c $path", "$path compiles" ) or BAILOUT();
	require_ok( $path );
	};

subtest process_args => sub {
	can_ok( $class, 'process_args' );
	};

subtest run => sub {
	can_ok( $class, 'run' );

	};

subtest config => sub {
	pass();
	};


subtest feeds => sub {
	pass();
	};

done_testing();
