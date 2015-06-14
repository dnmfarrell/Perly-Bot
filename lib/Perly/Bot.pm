package Perly::Bot;
use warnings;
use strict;
use 5.10.1;
use HTTP::Tiny;
use YAML::XS qw/LoadFile DumpFile/;
use Time::Piece;
use Time::Seconds;
use Try::Tiny;
use List::Util 'any';
use Carp;
use Perly::Bot::Feed;
use Encode 'encode';
use Perly::Bot::Media::Twitter;
use Perly::Bot::Media::Reddit;
use Perly::Bot::Cache;

# modulino pattern
__PACKAGE__->run( load_config('config.yml') ) unless caller();

=head1 FUNCTIONS

=head2 load_config ($path)

Loads the variables in the config file and adds additionally
required variables.

=cut

sub load_config
{
  my $config = LoadFile(shift);

  try
  {
    $config->{datetime_now}  = gmtime;
    $config->{age_threshold} = ONE_DAY;
    $config->{debug} = 1 if $ENV{PERLY_BOT_DEBUG};

    # init cache
    my $cache = Perly::Bot::Cache->new(
      $config->{cache}{path},
      $config->{cache}{expiry_secs}
    );
    $config->{cache} = $cache;

    # load media objects
    # fallback on ENV vars if not present in config file
    unless (defined $config->{reddit})
    {
      $config->{reddit} = {
        username         => $ENV{REDDIT_USERNAME},
        password         => $ENV{REDDIT_PASSWORD},
        subreddit        => 'perl',
        session_filepath => 'logs/reddit_session_data.json',
      };
    }
    $config->{media}{reddit} = Perly::Bot::Media::Reddit->new($config);

    unless (defined $config->{twitter})
    {
      $config->{twitter} = {
        consumer_key     => $ENV{TWITTER_CONSUMER_KEY},
        consumer_secret  => $ENV{TWITTER_CONSUMER_SECRET},
        access_token     => $ENV{TWITTER_ACCESS_TOKEN},
        access_secret    => $ENV{TWITTER_ACCESS_SECRET},
        hashtag          => '#perl',
      };
    }
    $config->{media}{twitter} = Perly::Bot::Media::Twitter->new($config);

    return $config;
  }
  catch
  {
    log_error("load_config encountered an error: $_", $config->{error_log_path});
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
      trawl_blog($feed_args, $cache, $config);
    }
    catch
    {
      log_error("Error processing $feed_args->{url} $_", $config->{error_log_path});
    };
  }
}

=head2 trawl_blog

Walks through an arrayref of C<Perly::Bot::Feed::Post> objects and decides to post them
or not.

=cut

sub trawl_blog
{
  my ($feed_args, $cache, $config) = @_;

  my $feed = Perly::Bot::Feed->new($feed_args);
  state $ua = HTTP::Tiny->new( agent => $config->{agent_string} );
  my $response = $ua->get($feed->url);

  if ($response->{success})
  {
    # coerce to utf8, some pages contain utf8 but fail to declare the encoding as utf8
    my $utf8_content = encode('UTF-8', $response->{content});
    my $blog_posts = $feed->get_posts($utf8_content);

    foreach my $post (@$blog_posts)
    {
      if ( should_emit($post, $cache, $config) )
      {
        emit($post, $feed->social_media_targets, $cache, $config);
      }
    }
  }
  else
  {
    log_error(
      "Error requesting $response->{url}. $response->{status} $response->{reason}",
      $config->{error_log_path});
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
  my ($post, $cache, $config) = @_;

  # posts must mention a Perl keyword to be considered relevant
  my $looks_perly = qr/\b(?:perl|cpan|cpanm|moose|metacpan|module|timtowdi?)\b/i;

  $post->datetime > $config->{datetime_now} - $config->{age_threshold}
  && $config->{datetime_now} - $post->datetime > $post->delay_seconds
  && !$cache->has_posted($post)
  && any { $_ // '' =~ /$looks_perly/ } $post->title, $post->description
}

=head2 emit

Sends the blog post to C<Perly::Bot::Media> objects for posting.

=cut

sub emit
{
  my ($post, $social_media_targets, $cache, $config) = @_;

  $cache->save_post($post);

  if ($config->{debug})
  {
    printf STDOUT "Not posting %s as program is in debug mode\n", $post->root_url;
    return;
  }

  foreach my $media (@$social_media_targets)
  {
    if (my $media = $config->{media}{$media})
    {
      $media->send($post);
    }
    else
    {
      log_error("post() didn't recognize $media", $config->{error_log_path});
    }
  }
}

sub log_error
{
  my ($error, $error_log_path) = @_;
  open my $error_log, '>>', $error_log_path or die $!;
  my $timestamp = gmtime;
  say $error_log $timestamp->datetime . "\t$error";
}

1;
