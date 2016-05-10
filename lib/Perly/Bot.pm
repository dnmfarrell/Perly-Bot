use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

package Perly::Bot;
use open qw(:std :utf8);
use lib 'lib';

use namespace::autoclean;
use Log::Log4perl;
use Log::Log4perl::Level;
use Path::Tiny;
use Perly::Bot::Config;
use Data::Dumper;

our $VERSION = '0.202';

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

=encoding utf8

=head1 NAME

Perly::Bot - repost Perl content to social media

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS

=head2 run ($package, $config_file)

The main routine, trawls blog feeds for new posts.

=cut

my $logger = Log::Log4perl->get_logger();

sub run ( $package, $opts ) {
  $logger->level( $opts->{log_level} || $INFO );
  $logger->debug( sprintf "logger level: %s\n", $logger->level );
  $logger->debug("Config file is [$opts->{config}]");

  my $config = Perly::Bot::Config->new( $opts->{config} );
  unless ($config) {
    $logger->logdie("Could not read configuration from [$opts->{config}]");
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
      my $emit = eval { $post->should_emit };
      if ($@) {
        $logger->error($@);
      }
      next unless !$@ && $emit;
      $emitted += emit($post);

      # be nice to APIs
      sleep(2);
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

  if ( $logger->is_trace ) {
    $logger->debug( sprintf "TRACE MODE: Not posting [%s]", $post->title );
    return 0;
  }

  my $config  = Perly::Bot::Config->get_config;
  my $cache   = $config->cache;
  my @errors  = ();
  my $emitted = 0;

  for my $media_target ( $post->feed->media_targets->@* ) {
    next unless $config->has_media_object($media_target);
    $logger->info( sprintf "Media target is [%s]", $media_target );
    my $media = $config->get_media_object($media_target);
    my $res = eval { $media->send($post) };

    if ( $@ || !$res ) {
      my $error = sprintf 'Could not send post! [%s] %s', $post->title, $@;
      $logger->error($error);
      push @errors, $error;
    }
    else {
      $emitted = 1;
    }

    unless ( eval { $cache->save_post($post) } ) {
      my $error = sprintf "Error caching [%s]: $@", $post->title;
      $logger->error($error);
      push @errors, $error;
    }
  }
  $logger->info( sprintf "[%d] errors for [%s]", scalar @errors, $post->title );
  return $emitted;
}

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
