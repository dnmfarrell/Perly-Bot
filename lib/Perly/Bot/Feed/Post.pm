use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

package Perly::Bot::Feed::Post;

use namespace::autoclean;
use Carp;
use HTML::Entities;
use HTTP::Tiny;
use List::Util 'any';
use Log::Log4perl;
use URI;

use base 'Class::Accessor';
Perly::Bot::Feed::Post->mk_accessors(
  qw/url title description datetime proxy delay_seconds twitter feed/);

my $logger = Log::Log4perl->get_logger();

=encoding utf8

=head1 NAME

Perly::Bot::Feed::Post - process a social media post

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS

=head2 clean_url

Removes the query component of the url. This is to reduce the risk of posting duplicate urls with different query parameters.

=cut

sub clean_url
{
  my ( $self, $url ) = @_;
  my $uri = URI->new($url);
  return $uri->scheme . '://' . $uri->host . $uri->path;
}

=head2 root_url

Returns the clean url, if the blog post url is a proxy, it will follow the proxy url and return the ultimate location the URL redirects to.

=cut

sub root_url
{
  my ($self) = @_;
  return $self->clean_url( $self->url ) unless $self->proxy;

  # if we've already retrieved the root url, don't pull it again
  return $self->{_root_url} if exists $self->{_root_url};

  my $response = HTTP::Tiny->new->get( $self->url );

  if ( $response->{success} )
  {
    $self->{_root_url} = $self->clean_url( $response->{url} );
    return $self->{_root_url};
  }
  else
  {
    $logger->logcroak(
      "Error requesting $response->{url}. $response->{status} $response->{reason}"
    );
  }
}

=head2 decoded_title

Returns the blog post title decoded from html using L<HTML::Entities>. This is required because some titles have HTML encoded characters in them.

=cut

sub decoded_title
{
  my ($self) = @_;
  decode_entities( $self->title );
}

=head2 should_emit

The logic to decide if a blog post should be emitted or not. This is:

- if the post is recent
- not too new to exceed the delay (to allow authors to post their own links)
- it looks Perl-related and is not already posted

Feel free to subclass and override this logic with your own needs for a particular
post type!

=cut

sub should_emit ( $post )
{
  my $config = Perly::Bot::Config->get_config;
  my $cache  = $config->cache;

  # posts must mention a Perl keyword to be considered relevant

  my $time_now = gmtime;

  # is the post fresh enough?
  $post->datetime > $time_now - $post->age_threshold_secs

  # have we delayed posting enough for the owner to post themselves?
  && $time_now - $post->datetime > $post->delay_seconds

  # is the post cached?
  && !$cache->has_posted($post)

  # does it looks Perl related?
  && $post->looks_perly
}

=head2 age_threshold_secs

Returns the configured age_threshold_secs value. You can override this
to decide a value based on anything you like.

=cut

sub age_threshold_secs
{
  Perly::Bot::Config->get_config->age_threshold_secs;
}

=head2 looks_perly( POST )

Returns true if the post looks like it's about Perl. Since it's a method
you can override this in specialized post types.

=cut

sub looks_perly ( $post )
{
  state $looks_perly =
    qr/\b(?:perl|perl6|cpan|cpanm|moose|metacpan|module|timtowdi|yapc|\:\:)\b/i;

  any { ( $_ // '' ) =~ /$looks_perly/ } $post->title, $post->description;
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

