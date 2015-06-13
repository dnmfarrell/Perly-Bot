package Perly::Bot::Media::Twitter;
use Carp;
use Try::Tiny;
use Net::Twitter::Lite::WithAPIv1_1;
use Role::Tiny::With;

with 'Perly::Bot::Media';

=head1 DESCRIPTION

This class is for posting to Twitter

=cut

=head2 new ($config)

Constructor, returns a new C<Perly::Bot::Media::Twitter> object.

Requires hashref containing these key values:

  agent_string => '...',
  twitter => {
    consumer_key    => '...',
    consumer_secret => '...',
    access_token    => '...',
    access_secret   => '...',
    hashtag         => '...', # optional
  }

C<agent_string> can be any string you like, it will be sent to Twitter when tweeting.

The Twitter key/secrets come from the Twitter API. You need to register an application
with Twitter in order to obtain them.

C<hashtag> is the hashtag to append to any tweets issued. This will be omitted if there
is not enough chars left (e.g. if the blog post title is extremely long). This is optional.

=cut

sub new
{
  my ($class, $config) = @_;

  unless ($config->{agent_string}
          && $config->{twitter}{consumer_key}
          && $config->{twitter}{consumer_secret}
          && $config->{twitter}{access_token}
          && $config->{twitter}{access_secret})
  {
    croak 'config is missing required variables for ' . __PACKAGE__;
  }

  try
  {
    my $twitter = Net::Twitter::Lite::WithAPIv1_1->new(
          consumer_key        => $config->{twitter}{consumer_key},
          consumer_secret     => $config->{twitter}{consumer_secret},
          access_token        => $config->{twitter}{access_token},
          access_token_secret => $config->{twitter}{access_secret},
          ssl                 => 1,
          user_agent          => $config->{agent_string},
    );

    return bless {
      twitter_api => $twitter,
      hashtag     => ($config->{twitter}{hashtag} || ''),
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
