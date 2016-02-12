use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

package Perly::Bot;
use open qw(:std :utf8);
use lib 'lib';

use List::Util 'any';
use Log::Log4perl;
use Log::Log4perl::Level;
use Mojo::UserAgent;
use Path::Tiny;
use Perly::Bot::Cache;
use Perly::Bot::Feed;
use Time::Piece;
use Time::Seconds;
use Try::Tiny;

our $VERSION = 0.10;

Log::Log4perl->init( \ <<'LOG');
  layout_class   = Log::Log4perl::Layout::PatternLayout
    layout_pattern = %d %F{1} %L> %m%n

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
__PACKAGE__->run( @ARGV ) unless caller();

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


=head2 run ($package, $config_file)

The main routine, trawls blog feeds for new posts.

=cut

sub run ( $package, $config_file )
{
  my $config = Perly::Bot::Config->new( $config_file );

  my $cache = $config->cache;
  my $feeds = $config->feeds;

  $logger->debug( sprintf "Checking %s feeds\n", scalar @$feeds );

  # Loop through feeds, check for new posts
  for my $feed_args (@$feeds)
  {
    try
    {
      # inject the media config into the feed args
      $feed_args->{media_config} = $config->media;
      my $feed = Perly::Bot::Feed->new( $feed_args );
      return unless $feed->active;
      trawl_blog( $feed, $cache );
    }
    catch
    {
      $logger->error("Error processing $feed_args->{url} $_");
    };
  }
}

=head2 trawl_blog

Walks through an arrayref of C<Perly::Bot::Feed::Post> objects and decides to post them
or not.

=cut

sub trawl_blog ( $feed, $cache )
{
  my $config = Perly::Bot::Config->get_config;

  my $ua = HTTP::Tiny->new( agent => $config->agent_string );
  my $response = $ua->get( $feed->url );

  if ( my $content = fetch_feed( $feed ) )
  {
    my $blog_posts = $feed->get_posts($content);

    $logger->debug( scalar @$blog_posts . ' posts found' );

    foreach my $post (@$blog_posts)
    {
      try
      {
        $logger->debug( sprintf "Testing %s", $post->title );

        if ( should_emit( $post, $cache ) && emit( $post, $feed ) )
        {
          $cache->save_post($post);
        }
      }
      catch
      {
        # exception thrown, cache the post so we dont
        # try to emit it again
        $cache->save_post($post);

        # rethrow the exception
        $logger->logdie($_);
      }
    }
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
  my ( $post, $cache ) = @_;

  my $config = Perly::Bot::Config->get_config;

  # posts must mention a Perl keyword to be considered relevant
  my $looks_perly =
    qr/\b(?:perl|perl6|cpan|cpanm|moose|metacpan|module|timtowdi|yapc|\:\:)\b/i;

  my $time_now = gmtime;

  # is the post fresh enough?
  $post->datetime > $time_now - $config->age_threshold_secs

    # have we delayed posting enough for the owner to post themselves?
    && $time_now - $post->datetime > $post->delay_seconds

    # is the post cached?
    && !$cache->has_posted($post)

    # does it looks Perl related?
    && any { ( $_ // '' ) =~ /$looks_perly/ } $post->title, $post->description;
}

=head2 emit

Sends the blog post to C<Perly::Bot::Media> objects for posting.

=cut

sub emit
{
  my ( $post, $feed ) = @_;

  $logger->debug( sprintf "Not posting %s as program is in debug mode",
    $post->root_url );
  return 0 if $logger->is_debug;

  $_->send($post) for values @{ $feed->media };
  return 1;
}

sub fetch_feed
{
  my ( $feed ) = @_;


  state $ua = do
  {
    my $config = Perly::Bot::Config->get_config;
    my $ua = Mojo::UserAgent->new;
    $ua->transactor->name( $config->{agent_string} );
    $ua;
  };


  $logger->debug("Checking $feed->{url} ...");
  my $tx = $ua->get( $feed->url );

  if ( $tx->success )
  {
    my $content = $tx->res->text;    # decode
    $logger->debug( sprintf 'Received content length: %s', length($content) );
    return $content;
  }
  $logger->logdie( "Error requesting [%s]. [%s] [%s]",
    $feed->url, $tx->res->code, $tx->res->message );
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
