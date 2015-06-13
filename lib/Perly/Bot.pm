package Perly::Bot;
use warnings;
use strict;
use 5.10.1;
use Reddit::Client;
use HTTP::Tiny;
use YAML::XS qw/LoadFile DumpFile/;
use Time::Piece;
use Time::Seconds;
use Try::Tiny;
use List::Util 'any';
use Net::Twitter::Lite::WithAPIv1_1;
use Carp;
use Perly::Bot::Feed;
use Encode 'encode';

# Globals - these can be put in a config file
our $VERSION     = 0.06;
my $AGENT_STRING = "Perly_Bot/v$VERSION";
my $DATETIME_NOW = localtime;
my $AGE_THRESHOLD= ONE_DAY;
my $CACHE_AGE    = ONE_WEEK;
my $FEEDS_PATH   = 'feeds.yml';
my $CACHE_PATH   = 'logs/cached_urls.yml';
my $SESSION_PATH = 'logs/session_data.json';

# modulino pattern
__PACKAGE__->run($CACHE_PATH, $FEEDS_PATH) unless caller();

=head2 run

The main routine, trawls blog feeds for new posts.

=cut

sub run
{
  my ($package, $cache_path, $feeds_path) = @_;

  my $cache = LoadFile($cache_path);
  my $feeds = LoadFile($feeds_path);

  # Loop through feeds, check for new posts
  for my $feed_args ( @{$feeds} )
  {
    try
    {
      trawl_blog($feed_args, $cache);
    }
    catch
    {
      log_error("Error processing $feed_args->{url} $_");
    };
  }

  # update the cache on exit
  $cache = refresh_cache($cache);
  DumpFile( $cache_path, $cache )
}

=head2 trawl_blog

Walks through an arrayref of C<Perly::Bot::Feed::Post> objects and decides to post them
or not.

=cut

sub trawl_blog
{
  my ($feed_args, $cache) = @_;

  my $feed = Perly::Bot::Feed->new($feed_args);
  state $ua = HTTP::Tiny->new( agent => $AGENT_STRING );
  my $response = $ua->get( $feed->url );

  if ( $response->{success} )
  {
    # coerce to utf8, some pages contain utf8 but fail to declare the encoding as utf8
    my $utf8_content = encode('UTF-8', $response->{content});
    my $blog_posts = $feed->get_posts($utf8_content);

    foreach my $post (@$blog_posts)
    {
      if ( should_post($post, $cache) )
      {
        post($post, $feed->social_media_targets, $cache);
      }
    }
  }
  else
  {
    log_error("Error requesting $response->{url}. $response->{status} $response->{reason}");
  }
}

=head2 should_post

The logic to decide if a blog post should be posted or not. This is:

- if the post is recent
- not too new to exceed the delay (to allow authors to post their own links)
- it looks Perl-related and is not already posted

Feel free to subclass this module and override this logic with your own needs!

=cut

sub should_post
{
  my ($post, $cache) = @_;

  # posts must mention a Perl keyword to be considered relevant
  state $looks_perly = qr/\b(?:perl|cpan|cpanm|moose|metacpan|module|timtowdi?)\b/i;

  $post->datetime > $DATETIME_NOW - $AGE_THRESHOLD
  && $DATETIME_NOW - $post->datetime > $post->delay_seconds
  && !url_is_cached($cache, $post->root_url)
  && any { /$looks_perly/ } $post->title, $post->description
}

=head2 post

Sends the blog post to outward channels like Twitter and Reddit.

=cut

sub post
{
  my ($post, $social_media_targets, $cache) = @_;

  cache_url($cache, $post->root_url);

  if ($ENV{PERLY_BOT_DEBUG})
  {
    printf STDERR "Not posting %s as program is in debug mode\n", $post->root_url;
    return;
  }

  foreach my $media (@$social_media_targets)
  {
    if ($media eq 'twitter')
    {
      tweet_link($post, '#perl');
    }
    elsif ($media =~ 'reddit')
    {
      post_reddit_link($post, 'perl');
    }
    else
    {
      log_error("post() didn't recognize $media");
    }
  }
}

sub log_error
{
    open my $error_log, '>>', 'logs/error.log' or die $!;
    my $timestamp = localtime;
    say $error_log $timestamp->datetime . "\t$_[0]";
}

sub url_is_cached
{
    my ($cache, $url) = @_;
    any { $url eq $_->{url} } @$cache;
}

sub cache_url
{
    my ($cache, $url) = @_;
    push @$cache, { url => $url, datetime => $DATETIME_NOW->datetime };
}

# sieves out stale urls
sub refresh_cache
{
    my $cache = shift;
    [ grep {
        my $url_date =
          Time::Piece->strptime( $_->{datetime}, "%Y-%m-%dT%H:%M:%S" );
        $url_date > $DATETIME_NOW - $CACHE_AGE ? 1 : 0;
    } @$cache ];
}

=head2 post_reddit_link

Posts a link to a subreddit, requires the title, url and subreddit.

=cut

sub post_reddit_link
{
  my ($blog_post, $subreddit) = @_;

  my $session_file = $SESSION_PATH;
  my $reddit       = Reddit::Client->new(
    session_file => $session_file,
    user_agent   => $AGENT_STRING,
  );

  unless ( $reddit->is_logged_in )
  {
    unless ($ENV{REDDIT_USERNAME}
            && $ENV{REDDIT_PASSWORD})
    {
      croak "Env vars REDDIT_USERNAME, REDDIT_PASSWORD are not both defined";
    }
      $reddit->login( $ENV{REDDIT_USERNAME}, $ENV{REDDIT_PASSWORD} );
      $reddit->save_session();
  }

  $reddit->submit_link(
    subreddit => $subreddit,
    title     => $blog_post->decoded_title,
    url       => $blog_post->root_url
  );
  sleep(2); # throttle requests to avoid exceeding API limit
}

=head2 tweet_link

Tweet the link to twitter.

=cut

sub tweet_link
{
  my ($blog_post, $hashtag) = @_;

  # build tweet, max 140 chars
  my $tweet;

  if (length($blog_post->decoded_title) < 118)
  {
    $tweet = $blog_post->decoded_title . ' ' . $blog_post->root_url;
    if (length($blog_post->decoded_title . ' ' . $hashtag) < 118)
    {
      $tweet .= " $hashtag";
    }
  }
  else
  {
    $tweet = substr($blog_post->decoded_title, 0, 113) . "... " . $blog_post->root_url;
  }

  unless ($ENV{TWITTER_CONSUMER_KEY}
          && $ENV{TWITTER_CONSUMER_SECRET}
          && $ENV{TWITTER_ACCESS_TOKEN}
          && $ENV{TWITTER_ACCESS_SECRET})
  {
    croak 'Env vars TWITTER_CONSUMER_KEY TWITTER CONSUMER_SECRET TWITTER_ACCESS_TOKEN and TWITTER_ACCESS_SECRET are not all defined';
  }

  try
  {
    my $twitter = Net::Twitter::Lite::WithAPIv1_1->new(
          #traits              => [qw/API::RESTv1_1/],
          consumer_key        => $ENV{TWITTER_CONSUMER_KEY},
          consumer_secret     => $ENV{TWITTER_CONSUMER_SECRET},
          access_token        => $ENV{TWITTER_ACCESS_TOKEN},
          access_token_secret => $ENV{TWITTER_ACCESS_SECRET},
          ssl                 => 1,
          user_agent          => $AGENT_STRING,
    );

    $twitter->update($tweet);
  }
  catch
  {
    croak("Error tweeting $blog_post->{url} $blog_post->{title} " . $_->code . " " . $_->message . " " . $_->error);
  };
}

