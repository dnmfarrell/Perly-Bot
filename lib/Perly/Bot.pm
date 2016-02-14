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

our $VERSION = '0.101';

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

=head2 run ($package, $config_file)

The main routine, trawls blog feeds for new posts.

=cut

sub run ( $package, $config_file = catfile( $ENV{HOME}, '.perlybot', 'config.yml' ) )
{
  my $config = Perly::Bot::Config->new( $config_file );
  unless( $config ) {
    $logger->logdie( "Could not read configuration from [$config_file]" );
  	}

  # Loop through feeds, check for new posts
  for my $feed ( $config->feeds->@* )
  {
      my $posts = $feed->trawl_blog;
      foreach my $post ( $posts->@* )
      {
        next unless $post->should_emit;
        emit( $post );
      }
  }
}

=head2 emit

Sends the blog post to C<Perly::Bot::Media> objects for posting.

=cut

sub emit ( $post )
{
  $logger->debug( sprintf "Not posting %s as program is in debug mode",
    $post->root_url );
  return 0 if $logger->is_debug;

  my $cache = Perly::Bot::Config->get_config->cache;

  foreach my $media_target ( $post->feed->media->@* )
  {
    $_->send($post);
    eval { $cache->save_post( $post ) }
    	or $logger->logdie( $@ );
  }
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
