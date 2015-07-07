package Perly::Bot;
use warnings;
use strict;
use 5.10.1;
use Encode 'encode';
use HTTP::Tiny;
use List::Util 'any';
use Path::Tiny;
use Perly::Bot::Cache;
use Perly::Bot::Feed;
use Time::Piece;
use Time::Seconds;
use Try::Tiny;
use YAML::XS qw/LoadFile/;

our $VERSION = 0.08;
my $DEBUG = 0;

# modulino pattern
__PACKAGE__->run( load_config() ) unless caller();

=head1 FUNCTIONS

=head2 load_config ($path)

Loads the variables in the config file and adds additionally
required variables.

=cut

sub load_config
{
  # use local config or fallback on user config file
  my $config_path = -e 'config.yml'
    ? 'config.yml'
    : "$ENV{HOME}.perlybot/config.yml";

  # use canonpath for cross platform support
  my $config = LoadFile(Path::Tiny->new($config_path)->canonpath);

  try
  {
    $DEBUG = $ENV{PERLY_BOT_DEBUG} // $config->{debug};

    $config->{agent_string} = $config->{agent_string} . $VERSION;

    # init cache
    my $cache = Perly::Bot::Cache->new(
      $config->{cache}{path},
      $config->{cache}{expiry_secs}
    );
    $config->{cache} = $cache;

    # load media objects
    for my $module_name (keys %{$config->{media}})
    {
      eval "require $module_name";
      my $config_path = $config->{media}{$module_name}{config_path};
      my $args = LoadFile($config_path);
      $config->{media}{$module_name} =  $module_name->new($args);
    }

    return $config;
  }
  catch
  {
    open my $error_log, '>>', $config->{error_log_path} or die $!;
    my $timestamp = gmtime;
    say $error_log $timestamp->datetime . "\tload_config encountered an error: $_";
    exit 0;
  };
}

=head2 run ($package, $config)

The main routine, trawls blog feeds for new posts.

=cut

sub run
{
  my ($package, $config) = @_;

  my $cache = $config->{cache};
  my $feeds = LoadFile($config->{feeds_path});

  # Loop through feeds, check for new posts
  for my $feed_args ( @{$feeds} )
  {
    try
    {
      # inject the loaded media into feed_args
      $feed_args->{media} = $config->{media};

      trawl_blog($feed_args,
        $cache,
        $config->{agent_string},
        $config->{should_emit}{age_threshold_secs},
      );
    }
    catch
    {
      open my $error_log, '>>', $config->{error_log_path} or die $!;
      my $timestamp = gmtime;
      say $error_log $timestamp->datetime . "\tError processing $feed_args->{url} $_";
    };
  }
}

=head2 trawl_blog

Walks through an arrayref of C<Perly::Bot::Feed::Post> objects and decides to post them
or not.

=cut

sub trawl_blog
{
  my ($feed_args, $cache, $agent_string, $age_threshold_secs) = @_;

  my $feed = Perly::Bot::Feed->new($feed_args);
  return unless $feed->active;

  state $ua = HTTP::Tiny->new( agent => $agent_string);
  my $response = $ua->get($feed->url);

  if ($response->{success})
  {
    # coerce to utf8, some pages contain utf8 but fail to declare the encoding as utf8
    my $utf8_content = encode('UTF-8', $response->{content});
    my $blog_posts = $feed->get_posts($utf8_content);

    foreach my $post (@$blog_posts)
    {
      try
      {
        if ( should_emit($post, $cache, $age_threshold_secs)
             && emit($post, $feed) )
        {
          $cache->save_post($post);
        }
      }
      catch
      {
        # exception thrown, cache the post so we don't
        # try to emit it again
        $cache->save_post($post);

        # rethrow the exception
        die $_;
      }
    }
  }
  else
  {
    die "Error requesting $response->{url}. $response->{status} $response->{reason}";
  }
}

=head2 should_emit

The logic to decide if a blog post should be emitted or not. This is:

- if the post is recent
- not too new to exceed the delay (to allow authors to post their own links)
- it looks Perl-related and is not already posted

Feel free to subclass and override this logic with your own needs!

=cut

sub should_emit
{
  my ($post, $cache, $age_threshold_secs) = @_;

  # posts must mention a Perl keyword to be considered relevant
  my $looks_perly = qr/\b(?:perl|cpan|cpanm|moose|metacpan|module|timtowdi?)\b/i;

  my $time_now = gmtime;

  # is the post fresh enough?
  $post->datetime > $time_now - $age_threshold_secs

  # have we delayed posting enough for the owner to post themselves?
  && $time_now - $post->datetime > $post->delay_seconds

  # is the post cached?
  && !$cache->has_posted($post)

  # does it looks Perl related?
  && any { $_ // '' =~ /$looks_perly/ } $post->title, $post->description
}

=head2 emit

Sends the blog post to C<Perly::Bot::Media> objects for posting.

=cut

sub emit
{
  my ($post, $feed) = @_;

  if ($DEBUG)
  {
    printf STDOUT "Not posting %s as program is in debug mode\n", $post->root_url;
    return 0;
  }
  $_->send($post) for values %{$feed->media};
  return 1;
}

1;
