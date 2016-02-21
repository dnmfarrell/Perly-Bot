use v5.22;
use utf8;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

package Perly::Bot::Config;

use namespace::autoclean;
use Perly::Bot::CommonSetup;
use File::Spec::Functions;
use Data::Dumper;

our $VERSION = '1.001';

my $logger = Log::Log4perl->get_logger();


BEGIN {
my $self;

sub new ( $class, $file = catfile( $ENV{HOME}, '.perlybot', 'config' ) ) {
	$logger->debug( "config file is [$file]" );
	return $self if defined $self;

	$self = bless {}, $class;

	$self->load_config( $file );

	$self->init_cache;
	$self->load_media;


	$self;
	}

sub get_config ( $class ) {
	unless( $class->_config_setup ) {
		$logger->logcroak( "Config is not setup! Call new() first" );
		}

	$self;
	}

sub _config_setup ( $class ) { defined $self }
}

sub AUTOLOAD ( $self ) {
	our $AUTOLOAD;

	my( $method ) = $AUTOLOAD =~ m/.+::(.+)/;

	if( ! ref $self ) {
		$logger->logcarp( "$method is not a class method" );
		}
	elsif( exists $self->{$method} ) {
		return $self->{$method};
		}
	else {
		$logger->error( "$method is not configured" );
		return;
		}
	}


sub load_config ( $self,
	$file = do { 'config.yml' ? 'config.yml' : "$ENV{HOME}/.perly_bot/config.yml" }
	) {
	state $module = require YAML::XS;
	$self->{_file} = $file;

	# use canonpath for cross platform support
	my $file_hash = YAML::XS::LoadFile( Path::Tiny->new($file)->canonpath );
	%$self = ( $self->%*, $file_hash->%* );

    $self->{perlybot_path} = $self->perlybot_path
    	// catfile( $ENV{HOME}, '.perly_bot' );
	}

sub init_cache ( $self, $cache_class='Perly::Bot::Cache' ) {
    # init cache

    $self->{cache}{path} = $self->_full_path_or_resolve( $self->{cache}{path} );

    $logger->logdie( "Cache class <$cache_class> does not look like a valid namespace!" )
    	unless $cache_class =~ / \A [A-Z0-9_]+ ( :: [A-Z0-9_]+ )* \z /xi;
	state $module = do {
		my $rc = eval "require $cache_class; 1";
		if( $@ ) { $logger->warn( "$@" ) }
		$rc;
		};
    $self->{cache}{class}  = $cache_class;
    $self->{cache}{object} = $cache_class->new;
	$self;
	}

sub cache        ( $self ) { $self->{cache}{object}      }
sub cache_path   ( $self ) { $self->{cache}{path}        }
sub cache_expiry ( $self ) { $self->{cache}{expiry_secs} }

sub load_media ( $self ) {
	$logger->trace( "load_media" );
	state $module = require YAML::XS;
    foreach my $module_name ( keys $self->media->%* ) {
    	unless( $module_name =~ m/ \A [A-Z0-9_]+ ( :: [A-Z0-9_]+ )+ \z /xi ) {
    		$logger->error( "Invalid namespace [$module_name]!" );
    		next;
    		}

		my $config_path = catfile(
			$self->perlybot_path,
			$self->media->{$module_name}{config_path}
			);

		$self->add_media_object( $module_name, $config_path );
    	}

	return $self;
	}

sub add_media_object ( $self, $module_name, $config_path ) {
	$logger->debug( "Module name [$module_name] has config path [$config_path]" );
	unless( $module_name =~ m/ \A [A-Z0-9_]+ ( :: [A-Z0-9_]+ )+ \z /xi ) {
		$logger->warn( "Invalid namespace [$module_name]!" );
		next;
		}

	unless( eval "require $module_name; 1" ) {
		$logger->error( "Could not load [$module_name]: $@" );
		return;
		}

	my $this = $self->{media}{$module_name} = {};

	$this->{defaults} = $module_name->config_defaults;
	$this->{media_config} = eval { YAML::XS::LoadFile( $config_path ) } // {};

	my %params = map { $this->{$_}->%* } qw(defaults media_config);

	$self->{media}{$module_name}{params} = \%params;

	my $object = eval { $module_name->new( \%params ) };
	unless( ref $object ) {
		$logger->logcroak( "Media config is " . Dumper( \%params ) );
		$logger->logcroak( "Could not make object for [$module_name]! $@" );
		return;
		}

	$self->{media}{$module_name}{object} = $object;
	}

sub has_media_object ( $self, $module_name ) {
	my $has = eval{ defined $self->media->{$module_name}{object} };
	if( $@ ) {
		$logger->warn( "Could not check for $module_name: $@" );
		}

	return $has;
	}

sub get_media_object ( $self, $module_name ) {
	return eval { $self->media->{$module_name}{object} };
	}

sub get_media_classes ( $self ) {
	return keys $self->media->%*;
	}

sub get_all_media_objects ( $self ) {
	my @objects;
	foreach my $module_name ( $self->get_media_classes ) {
		next unless $self->has_media_object( $module_name );
		push @objects, $self->get_media_object( $module_name );
		}
	\@objects;
	}

sub add_media_type ( $self, $type ) {
	push @{ $self->{media} }, $type;
	}

sub media_config ( $self, $class ) {
	unless( exists $self->{media}{$class}{config} ) {
		$logger->logwarn( "There's no config for media target $class" );
		return;
		}

	my $args = $self->{media}{$class}{config};
	unless( ref $args eq ref {} ) {
		$logger->logwarn( "Data for media target $class isn't a hash ref" );
		return;
		}

	$args;
	}

sub media_targets ( $self ) {
	return $self->{media_targets}->@*;
	}

sub _full_path_or_resolve ( $self, $path ) {
	$logger->debug( "Resolving path [$path]" );
	return $path if File::Spec->file_name_is_absolute( $path );

	return File::Spec->rel2abs( $path, $self->perlybot_path )
	}

sub feeds_path ( $self ) {
	my $path = $self->_full_path_or_resolve( $self->{feeds_path} );
	$logger->debug( "The feeds path is [$path]" );
	return $path;
	}

sub feeds ( $self ) {
	state $module =
		require YAML::XS,
		require Perly::Bot::Feed;

	my $config = Perly::Bot::Config->get_config;

	state $feeds_file = do {
		YAML::XS::LoadFile( $config->feeds_path );
		};
	state $feeds = [];
	return $feeds if @$feeds;

	foreach my $feed_info ( $feeds_file->@* ) {
		my $feed = Perly::Bot::Feed->new( $feed_info );
		push @$feeds, $feed if $feed->is_active;
		}

	$feeds;
	}

sub agent_string ( $self ) {
	$self->{agent_string} . $VERSION;
	}

sub	age_threshold_secs ( $self ) {
	$self->{should_emit}{age_threshold_secs}
	}

sub reddit               ( $self ) { $self->media->{'Perly::Bot::Media::Reddit'}{params} // {} }
sub subreddit            ( $self ) { $self->reddit->{subreddit}     }
sub reddit_client_id     ( $self ) { $self->reddit->{client_id}     }
sub reddit_client_secret ( $self ) { $self->reddit->{client_secret} }
sub reddit_username      ( $self ) { $self->reddit->{username}      }
sub reddit_password      ( $self ) { $self->reddit->{password}      }

sub twitter                 ( $self ) { $self->media->{'Perly::Bot::Media::Twitter'}{params} // {}   }
sub twitter_consumer_key    ( $self ) { $self->{consumer_key}    }
sub twitter_consumer_secret ( $self ) { $self->{consumer_secret} }
sub twitter_access_token    ( $self ) { $self->{access_token}    }
sub twitter_access_secret   ( $self ) { $self->{access_secret}   }

