package Perly::Bot::Media::Twitter;
use v5.22;
use warnings;
no warnings qw(experimental::signatures experimental::postderef);
use feature qw(signatures postderef);
use parent qw(Perly::Bot::Media::Base);
use Net::Twitter::Lite::WithAPIv1_1;
use Carp 'croak';

my $logger = Log::Log4perl->get_logger();

=encoding utf8

=head1 NAME

Perly::Bot::Media::Twitter - repost Perl content to Twitter

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

sub new ( $class, $args ) {
  return bless {
    twitter_api => Net::Twitter::Lite::WithAPIv1_1->new(%$args),
    hashtag     => ( $args->{hashtag} || 'perl' ),
  }, $class;
}

sub _build_tweet ( $self, $blog_post ) {
  my $title   = $blog_post->decoded_title;
  my $url     = $blog_post->root_url;
  my $via     = $blog_post->twitter ? 'via @' . $blog_post->twitter : '';
  my $hashtag = $self->{hashtag};

  my $char_count = 140;
  $char_count -= $url =~ /^https/ ? 23 : 22;

  if ( length( join ' ', $title, $via, $hashtag ) < $char_count ) {
    return $hashtag
      ? join ' ', $title, $via, $url
      : join ' ', $title, $via, $url, $hashtag;
  }
  elsif ( length( join ' ', $title, $via ) < $char_count ) {
    return join ' ', $title, $via, $url;
  }
  else {
    # 5 chars = 3 ellipses plus 2 spaces
    my $shortened_title =
      substr( $title, 0, $char_count - 5 - length($via) ) . '...';
    return join ' ', $shortened_title, $via, $url;
  }
}

sub send ( $self, $blog_post ) {
  my $tweet = $self->_build_tweet($blog_post);
  croak 'Error preparing tweet text' unless $tweet;
  $logger->debug( sprintf "Tweet is [%s]", $tweet );

  my $res = eval { $self->{twitter_api}->update($tweet) };
  if ($@) {
    if ( ref $@ && $@->isa('Net::Twitter::Error') ) {
      croak sprintf 'Error tweeting %s %s %s', $@->code, $@->message, $@->error;
    }
    else {
      croak sprintf 'Error tweeting %s', $@;
    }
  }
  return $res;
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
