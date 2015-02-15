#!/usr/bin/env perl

package Perly::Bot;
use 5.10.3;
use warnings;
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

# Globals - these can be put in a config file
our $VERSION      = 0.02;
my $agent_string = "Perly_Bot/v$VERSION";
# posts must mention a Perl keyword to be considered relevant
my $looks_perly = qr/\b(?:perl|cpan|cpanminus|moose|metacpan|modules?)\b/i;
my $datetime_now = localtime;
my $age_threshold= ONE_DAY;
my $ua           = HTTP::Tiny->new( agent => $agent_string );
my $feeds_path   = 'feeds.yml';
my $feeds        = LoadFile($feeds_path);
my $cache_path   = 'logs/cached_urls.yml';
my $cache        = LoadFile($cache_path);
my $session_path = 'logs/session_data.json';
open my $ERROR_LOG, '>>', 'logs/error.log' or die $!;
# end globals

# modulino pattern
__PACKAGE__->run() unless caller();

sub run
{
  # Loop through feeds, check for new posts
  for my $feed_args ( @{$feeds} )
  {
    try
    {
      my $feed = Perly::Bot::Feed->new($feed_args);

      next unless $feed->active;

      my $date_format = $feed->date_format;
      my $date_name   = $feed->date_name;

      my $response = $ua->get( $feed->url );
      if ( $response->{success} )
      {
        my $blog_posts = $feed->get_posts($response->{content});

        foreach my $post (@$blog_posts)
        {
          if ( $post->datetime > $datetime_now - $age_threshold
               && any { /$looks_perly/ } $post->title, $post->description )
          {
            # do something
            post_link($post, $feed->social_media_targets);
          }
        }
      }
      else
      {
        log_error("Error requesting $response->{url}. $response->{status} $response->{reason}");
      }
    }
    catch # something went wrong, log it
    {
      log_error("Error processing $feed_args->{url} $_");
    };
  }
}

sub post_link
{
  my ($post, $social_media_targets) = @_;

  unless (url_is_cached($post->root_url))
  {
    cache_url($post->root_url);

    foreach my $media (@$social_media_targets)
    {
      if ($media =~ /twitter/)
      {
        tweet($post, '#perl_community');
      }
      elsif ($media =~ /reddit/)
      {
        post_reddit_link($post, 'perl');
      }
      else
      {
        log_error("post_link() didn't recognize $media");
      }
    }
  }
}

sub log_error
{
    my $timestamp = localtime;
    say $ERROR_LOG $timestamp->datetime . "\t$_[0]";
}

sub url_is_cached
{
    my ($cache, $url) = @_;
    any { $url eq $_->{url} } @$cache;
}

sub cache_url
{
    my ($cache, $url) = @_;
    push @$cache, { url => $url, datetime => $datetime_now->datetime };
}

# sieves out stale urls
sub refresh_cache
{
    my $cache = shift;
    grep {
        my $url_date =
          Time::Piece->strptime( $_->{datetime}, "%Y-%m-%dT%H:%M:%S" );
        $url_date > $datetime_now - $age_threshold ? 1 : 0;
    } @$cache;
}

=head2 post_reddit_link

Posts a link to a subreddit, requires the title, url and subreddit.

=cut

sub post_reddit_link
{
  my ($blog_post, $subreddit) = @_;

  my $session_file = $session_path;
  my $reddit       = Reddit::Client->new(
    session_file => $session_file,
    user_agent   => $agent_string,
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

  if (length($blog_post->decoded_title) <= 117)
  {
    $tweet = $blog_post->decoded_title . ' ' . $blog_post->root_url;
  }
  else
  {
    $tweet = substr($blog_post->decoded_title, 0, 113) . "... " . $blog_post->root_url;
  }

  if (length($tweet . $hashtag) < 139) # allow for a space char
  {
      $tweet .= " $hashtag";
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
          user_agent          => $agent_string,
    );

    $twitter->update($tweet);
  }
  catch
  {
    croak("Error tweeting $blog_post->{url} $blog_post->{title} " . $_->code . " " . $_->message . " " . $_->error);
  };
}

# update the cache on exit
END {
  $cache = refresh_cache($cache);
  DumpFile( $cache_path, $cache )
};

