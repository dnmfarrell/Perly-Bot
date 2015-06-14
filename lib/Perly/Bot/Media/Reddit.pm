package Perly::Bot::Media::Reddit;
use Carp;
use Try::Tiny;
use Reddit::Client;
use Role::Tiny::With;

with 'Perly::Bot::Media';

=head1 DESCRIPTION

This class is for posting to Reddit

=cut

=head2 new ($args)

Constructor, returns a new C<Perly::Bot::Media::Reddit> object.

Requires hashref containing these key values:

  agent_string => '...',
  reddit => {
    username => '...',
    password => '...',
    session_filepath  => '...',
    subreddit   => '...',
  }

C<agent_string> can be any string you like, it will be sent to Reddit when posting.

C<session_filepath> is a path where C<Reddit::Client> will cache the session details.
It can be any path as long as the process has read and write access.

C<username> and C<password> are the Reddit account credentials to use for authentication.
B<IMPORTANT> ensure that the Reddit account has enough karma to post without requiring to
complete a CAPTCHA. Brand-new Reddit accounts have to complete these until they get some
karama (it's a bot filter).

=cut

sub new
{
  my ($class, $args) = @_;

  unless ($args->{agent_string}
          && $args->{username}
          && $args->{password}
          && $args->{session_filepath}
          && $args->{subreddit})
  {
    croak 'args is missing required variables for ' . __PACKAGE__;
  }

  try
  {
    my $reddit = Reddit::Client->new(
      session_file => $args->{session_filepath},
      user_agent   => $args->{agent_string},
    );

    unless ($reddit->is_logged_in)
    {
        $reddit->login($args->{username}, $args->{password});
        $reddit->save_session();
    }

    return bless {
      reddit_api => $reddit,
      subreddit  => $args->{subreddit},
    }, $class;
  }
  catch
  {
    croak "Error constructing Reddit API object: $_";
  };
}

sub send
{
  my ($self, $blog_post) = @_;

  $self->{reddit_api}->submit_link(
    subreddit => $self->{subreddit},
    title     => $blog_post->decoded_title,
    url       => $blog_post->root_url
  );
  sleep(2); # throttle requests to avoid exceeding API limit
}

1;
