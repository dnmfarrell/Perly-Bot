package Perly::Bot::Feed::Post;
use strict;
use warnings;
use URI;
use HTTP::Tiny;
use HTML::Entities;
use Carp;
use base 'Class::Accessor';

Perly::Bot::Feed::Post->mk_accessors(qw/url title description datetime proxy delay_seconds/);

=head2 clean_url

Removes the query component of the url. This is to reduce the risk of posting duplicate urls with different query parameters.

=cut

sub clean_url
{
    my ($self) = @_;
    my $uri = URI->new( $self->url );
    return $uri->scheme . '://' . $uri->host . $uri->path;
}

=head2 root_url

Returns the clean url, if the blog post url is a proxy, it will follow the proxy url and return the ultimate location the URL redirects to.

=cut

sub root_url
{
  my ($self) = @_;
  return $self->clean_url unless $self->proxy;

  # if we've already retrieved the root url, don't pull it again
  return $self->{_root_url} if $self->{_root_url};

  my $response = HTTP::Tiny->new->get($self->url);

  if ($response->{success})
  {
    $self->{_root_url} = $self->clean_url( $response->{url} );
    return $self->{_root_url};
  }
  else
  {
    croak "Error requesting $response->{url}. $response->{status} $response->{reason}";
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

1;

