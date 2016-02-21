use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

package Perly::Bot::Media::Twitter;
use parent qw(Perly::Bot::Media::Base);

use namespace::autoclean;
use Net::Twitter::Lite::WithAPIv1_1;

my $logger = Log::Log4perl->get_logger();

=encoding utf8

=head1 NAME

Perly::Bot::Media::Twitter - repost Perl content to Twitter

=head1 SYNOPSIS

=head1 DESCRIPTION

This class is for posting to Twitter

=cut

=head2 new ($args)

Constructor, returns a new C<Perly::Bot::Media::Twitter> object.

Requires hashref containing these key values:

  agent_string    => '...',
  consumer_key    => '...',
  consumer_secret => '...',
  access_token    => '...',
  access_secret   => '...',
  hashtag         => '...', # optional

C<agent_string> can be any string you like, it will be sent to Twitter when tweeting.

The Twitter key/secrets come from the Twitter API. You need to register an application
with Twitter in order to obtain them.

C<hashtag> is the hashtag to append to any tweets issued. This will be omitted if there
is not enough chars left (e.g. if the blog post title is extremely long). This is optional.

=cut

sub config_defaults ( $class, $config={} ) {
	state $defaults = {
		type                  => 'twitter',
		class                 => __PACKAGE__,
		consumer_key          => $ENV{PERLYBOT_TWITTER_CONSUMER_KEY}    // undef,
		consumer_secret       => $ENV{PERLYBOT_TWITTER_CONSUMER_SECRET} // undef,
		access_token          => $ENV{PERLYBOT_TWITTER_ACCESS_TOKEN}    // undef,
		access_token_secret   => $ENV{PERLYBOT_TWITTER_ACCESS_SECRET}   // undef,
		};

	$defaults;
	}

sub is_properly_configured ( $class, $config ) {

	0;

	}

sub new ( $class, $args = {} ) {
	state $module = require Net::Twitter::Lite::WithAPIv1_1;

	my $config = Perly::Bot::Config->get_config;

	my %params = (
		consumer_key           => $args->{consumer_key}    || $config->twitter_consumer_key,
		consumer_secret        => $args->{consumer_secret} || $config->twitter_consumer_secret,
		access_token           => $args->{access_token}    || $config->twitter_access_token,
		access_token_secret    => $args->{access_token_secret}   || $config->twitter_access_token_secret,
		ssl                    => 1,
		);

	#$logger->debug( sub { "Twitter params are " . Dumper( \%params ) } );

	if( grep { ! defined } values %params ) {





		}

    my $twitter = Net::Twitter::Lite::WithAPIv1_1->new( %params );

    return bless {
      twitter_api => $twitter,
      hashtag     => ( $args->{hashtag} || '' ),
    }, $class;
  }
  catch
  {
    $logger->logcroak("Error constructing Twitter API object: $_");
  };
}

sub _build_tweet ( $self, $blog_post ) {
  my $title   = $blog_post->decoded_title;
  my $url     = $blog_post->root_url;
  my $via     = $blog_post->twitter ? 'via @' . $blog_post->twitter : '';
  my $hashtag = $self->{hashtag};

  my $char_count = 140;
  $char_count -= $url =~ /^https/ ? 23 : 22;

  if ( length( join ' ', $title, $via, $hashtag ) < $char_count )
  {
    return join ' ', $title, $via, $hashtag, $url;
  }
  elsif ( length( join ' ', $title, $via ) < $char_count )
  {
    return join ' ', $title, $via, $url;
  }
  else
  {
    # 5 chars = 3 ellipses plus 2 spaces
    my $shortened_title =
      substr( $title, 0, $char_count - 5 - length($via) ) . '...';
    return join ' ', $shortened_title, $via, $url;
  }
}

sub send ( $self, $blog_post ) {
	eval { $self->{twitter_api}->update( $self->_build_tweet($blog_post) ); 1 }
		or $logger->logcroak( "Error tweeting $blog_post->{url} $blog_post->{title} "
        . $_->code . " "
        . $_->message . " "
        . $_->error );
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
