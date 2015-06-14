package Perly::Bot::Media::Twitter;
use Carp;
use Try::Tiny;
use Net::Twitter::Lite::WithAPIv1_1;
use Role::Tiny::With;

with 'Perly::Bot::Media';

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
    croak 'args is missing required variables for ' . __PACKAGE__;
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
    croak "Error constructing Twitter API object: $_";
  };
}

sub send
{
  my ($self, $blog_post) = @_;

  # build tweet, max 140 chars
  my $tweet;
  my $hashtag = $self->{hashtag};

  if (length($blog_post->decoded_title) < 118)
  {
    $tweet = $blog_post->decoded_title . ' ' . $blog_post->root_url;
    if (length($blog_post->decoded_title . ' ' . $hashtag) < 118)
    {
      $tweet .= " $hashtag";
    }
  }
  else
  {
    $tweet = substr($blog_post->decoded_title, 0, 113) . "... " . $blog_post->root_url;
  }
  try
  {
    $self->{twitter_api}->update($tweet);
  }
  catch
  {
    croak("Error tweeting $blog_post->{url} $blog_post->{title} " . $_->code . " " . $_->message . " " . $_->error);
  };
}
1;
