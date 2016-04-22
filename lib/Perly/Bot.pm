use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

package Perly::Bot;
use open qw(:std :utf8);
use lib 'lib';

use namespace::autoclean;
use Log::Log4perl::Level;
use Path::Tiny;
use Perly::Bot::CommonSetup;

our $VERSION = '0.201';

Log::Log4perl->init( \ <<'LOG');
  layout_class   = Log::Log4perl::Layout::PatternLayout
    layout_pattern = %d %F{1} %L> %m%n

    log4perl.rootLogger = WARN, Logfile

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
__PACKAGE__->run(@ARGV) unless caller();

=encoding utf8

=head1 NAME

Perly::Bot - repost Perl content to social media

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS

=head2 run ($package, $config_file)

The main routine, trawls blog feeds for new posts.

=cut

sub run ( $package,
  $config_file = catfile( $ENV{HOME}, '.perlybot', 'config.yml' ) )
{
  $logger->debug("Config file is [$config_file]");
  my $config = Perly::Bot::Config->new($config_file);
  unless ($config) {
    $logger->logdie("Could not read configuration from [$config_file]");
  }

  # Loop through feeds, check for new posts
  my $total_emitted = 0;
  my $feeds_count   = 0;

  for my $feed ( $config->feeds->@* ) {
    $feeds_count++;
    $logger->info( sprintf "Processing feed [%s]", $feed->url );
    my $posts = $feed->trawl_blog;
    $logger->info(
      sprintf "Found %d posts in [%s]",
      scalar @$posts,
      $feed->url
    );

    my $emitted = 0;
    for my $post ( $posts->@* ) {
      my $should_emit = $post->should_emit;

# $logger->debug( sprintf "Should emit is [%s] for [%s]", $should_emit, $post->title );
# $logger->debug( "Post is " . $post->dump );
      next unless $should_emit;

      # positive numbers are bad because they are errors
      my $result = emit($post);
      $emitted++;
      sleep(2);         # be nice to APIs
    }

    $total_emitted += $emitted;
    $logger->info( sprintf "Emitted [%d] posts for [%s]", $emitted,
      $feed->url );
  }

  $logger->info( sprintf "Emitted [%d] posts in [%d] feeds",
    $total_emitted, $feeds_count );
}

=head2 emit

Sends the blog post to C<Perly::Bot::Media> objects for posting.

=cut

sub emit ( $post ) {
  $logger->info( sprintf "Emitting [%s]", $post->title );

  if ( !$ENV{PERLYBOT_POST_ANYWAYS} && $logger->is_debug ) {
    $logger->debug( sprintf "DEBUG MODE: Not posting [%s]", $post->title );
    return [];
  }

  my $config = Perly::Bot::Config->get_config;
  my $cache  = $config->cache;

  my @failed_posts= ();

  foreach my $media_target ( $post->feed->media_targets->@* ) {
    $logger->debug( sprintf "Media target is [%s]", $media_target );
    my $media    = $config->get_media_object($media_target);
    my $response = $media->send($post);
    unless ( $response->success ) {
      $logger->error(
        "Could not send post! " . $response->to_string . " " . $post->title );
    }
    unless ( eval { $cache->save_post($post) } ) {
      $logger->logcarp( sprintf "Error caching [%s]: $@", $post->title );
    }
  }

  $logger->info( sprintf "[%d] errors for [%s]", scalar @failed_posts, $post->title );

  return \@failed_posts;
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
