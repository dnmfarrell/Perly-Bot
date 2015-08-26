package Perly::Bot::Media::Twitter;
use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Log::Log4perl::Level;
use Try::Tiny;
use Net::Twitter::Lite::WithAPIv1_1;
use Role::Tiny::With;

with 'Perly::Bot::Media';

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

sub new
{
  my ($class, $args) = @_;

  unless ($args->{agent_string}
          && $args->{consumer_key}
          && $args->{consumer_secret}
          && $args->{access_token}
          && $args->{access_secret})
  {
    $logger->logcroak( 'args is missing required variables for ' . __PACKAGE__ );
  }

  try
  {
    my $twitter = Net::Twitter::Lite::WithAPIv1_1->new(
          consumer_key        => $args->{consumer_key},
          consumer_secret     => $args->{consumer_secret},
          access_token        => $args->{access_token},
          access_token_secret => $args->{access_secret},
          user_agent          => $args->{agent_string},
          ssl                 => 1,
    );

    return bless {
      twitter_api => $twitter,
      hashtag     => ($args->{hashtag} || ''),
    }, $class;
  }
  catch
  {
    $logger->logcroak(  "Error constructing Twitter API object: $_" );
  };
}

sub _build_tweet
{
  my ($self, $blog_post) = @_;

  my $title   = $blog_post->decoded_title;
  my $url     = $blog_post->root_url;
  my $via     = $blog_post->twitter ? 'via ' . $blog_post->twitter : '';
  my $hashtag = $self->{hashtag};

  my $char_count = 140;
  $char_count -= $url =~ /^https/ ? 23 : 22;

  if (length(join ' ', $title, $via, $hashtag) < $char_count)
  {
    return join ' ', $title, $via, $hashtag, $url;
  }
  elsif (length(join ' ', $title, $via) < $char_count)
  {
    return join ' ', $title, $via, $url;
  }
  elsif (length($title) < $char_count)
  {
    return join ' ', $title, $url;
  }
  else
  {
    return substr($title, 0, $char_count - 4) . "... " . $url;
  }
}

sub send
{
  my ($self, $blog_post) = @_;

  try
  {
    $self->{twitter_api}->update( $self->_build_tweet($blog_post) );
  }
  catch
  {
    $logger->logcroak("Error tweeting $blog_post->{url} $blog_post->{title} " . $_->code . " " . $_->message . " " . $_->error);
  };
}

=back

=head1 TO DO

=head1 SEE ALSO

=head1 SOURCE AVAILABILITY

This source is part of a GitHub project.

	https://github.com/dnmfarrell/Perly-Bot

=head1 AUTHOR

David Farrell C<< <sillymoos@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015, David Farrell C<< <sillymoos@cpan.org> >>. All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
