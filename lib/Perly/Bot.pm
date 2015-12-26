package Perly::Bot;
use warnings;
use strict;
use 5.10.1;
use open qw(:std :utf8);
use lib 'lib';

use HTTP::Tiny;
use List::Util 'any';
use Log::Log4perl;
use Log::Log4perl::Level;
use Path::Tiny;
use Perly::Bot::Cache;
use Perly::Bot::Feed;
use Time::Piece;
use Time::Seconds;
use Try::Tiny;
use YAML::XS qw/LoadFile/;

our $VERSION = 0.10;

Log::Log4perl->init(\ <<'LOG');
  layout_class   = Log::Log4perl::Layout::PatternLayout
    layout_pattern = %d %F{1} %L> %m %n

    log4perl.rootLogger = WARN, Logfile, Screen

    log4perl.appender.Logfile  = Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename = perlybot.log
    log4perl.appender.Logfile.layout = ${layout_class}
    log4perl.appender.Logfile.layout.ConversionPattern = ${layout_pattern}
    log4perl.appender.Logfile.utf8 = 1

    log4perl.appender.Screen  = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.layout = ${layout_class}
    log4perl.appender.Screen.layout.ConversionPattern = ${layout_pattern}
    log4perl.appender.Screen.utf8 = 1
LOG

my $logger = Log::Log4perl->get_logger();
$logger->level( $ENV{PERLYBOT_LOG_LEVEL} // $INFO );

# modulino pattern
__PACKAGE__->run( load_config() ) unless caller();

=encoding utf8

=head1 NAME

Perly::Bot - repost Perl content to social media

=head1 SYNOPSIS

=head1 DESCRIPTION

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
    : "$ENV{HOME}/.perly_bot/config.yml";

  # use canonpath for cross platform support
  my $config = LoadFile(Path::Tiny->new($config_path)->canonpath);

  try
  {
    my $perlybot_home = exists $config->{perlybot_path}
      ? $config->{perlybot_path}
      : "$ENV{HOME}/.perly_bot";

    $config->{agent_string} = $config->{agent_string} . $VERSION;

    # init cache
    my $cache = Perly::Bot::Cache->new(
      "$perlybot_home/$config->{cache}{path}",
      $config->{cache}{expiry_secs}
    );
    $config->{cache} = $cache;

    # load media objects
    for my $module_name (keys %{$config->{media}})
    {
      my $config_path = "$perlybot_home/$config->{media}{$module_name}{config_path}";
      my $args = LoadFile($config_path);
      $config->{media}{$module_name} = $args;
    }
  }
  catch
  {
    $logger->logdie( "load_config encountered an error: $_" );
  };
  return $config;
}

=head2 run ($package, $config)

The main routine, trawls blog feeds for new posts.

=cut

sub run
{
  my ($package, $config) = @_;

  my $cache = $config->{cache};
  my $feeds = LoadFile($config->{feeds_path});

  $logger->debug( sprintf "Checking %s feeds\n", scalar @$feeds );

  # Loop through feeds, check for new posts
  for my $feed_args ( @$feeds )
  {
    try
    {
      # inject the media config into the feed args
      $feed_args->{media_config} = $config->{media};
      my $feed = Perly::Bot::Feed->new($feed_args);
      return unless $feed->active;

      trawl_blog($feed,
        $cache,
        $config->{agent_string},
        $config->{should_emit}{age_threshold_secs},
      );
    }
    catch
    {
      $logger->error( "Error processing $feed_args->{url} $_" );
    };
  }
}

=head2 trawl_blog

Walks through an arrayref of C<Perly::Bot::Feed::Post> objects and decides to post them
or not.

=cut

sub trawl_blog
{
  my ($feed, $cache, $agent_string, $age_threshold_secs) = @_;

  my $ua = HTTP::Tiny->new( agent => $agent_string);
  my $response = $ua->get($feed->url);

  if ($response->{success})
  {
    $logger->debug( "Checking $feed->{url} ... " );

    # decode the HTML and re-encode it, to avoid double-encoding
    # This should already be a Perl string since HTTP::Tiny does
    # that bit. However, I think it does it incorrectly.
    my $decoded_response = $response->{content};

    my $blog_posts = $feed->get_posts($decoded_response);

    $logger->debug( scalar @$blog_posts . ' posts found' );

    foreach my $post (@$blog_posts)
    {
      try
      {
        $logger->debug( sprintf "Testing %s", $post->title );

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
        $logger->logdie( $_ );
      }
    }
  }
  else
  {
    $logger->logdie( "Error requesting $response->{url}. $response->{status} $response->{reason}" );
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
  my $looks_perly = qr/\b(?:perl|perl6|cpan|cpanm|moose|metacpan|module|timtowdi|yapc|\:\:)\b/i;

  my $time_now = gmtime;

  # is the post fresh enough?
  $post->datetime > $time_now - $age_threshold_secs

  # have we delayed posting enough for the owner to post themselves?
  && $time_now - $post->datetime > $post->delay_seconds

  # is the post cached?
  && !$cache->has_posted($post)

  # does it looks Perl related?
  && any { ($_ // '') =~ /$looks_perly/ } $post->title, $post->description
}

=head2 emit

Sends the blog post to C<Perly::Bot::Media> objects for posting.

=cut

sub emit
{
  my ($post, $feed) = @_;

  $logger->debug( sprintf "Not posting %s as program is in debug mode", $post->root_url );
  return 0 if $logger->is_debug;

  $_->send($post) for values @{$feed->media};
  return 1;
}

=head1 TO DO

=head1 SEE ALSO

=head1 SOURCE AVAILABILITY

This source is part of a GitHub project.

  https://github.com/dnmfarrell/Perly-Bot

=head1 AUTHOR

David Farrell C<< <dfarrell@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015, David Farrell C<< <dfarrell@cpan.org> >>. All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
