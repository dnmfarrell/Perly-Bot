use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

package Perly::Bot::Media::Reddit;
use parent qw(Perly::Bot::Media::Base);

use namespace::autoclean;
use Mojo::Snoo::Subreddit;
use Perly::Bot::CommonSetup;

my $logger = Log::Log4perl->get_logger();

=encoding utf8

=head1 NAME

Perly::Bot::Media::Reddit - Post to Reddit

=head1 SYNOPSIS

  use Perly::Bot::Media::Reddit;

  my $poster = Perly::Bot::Media::Reddit->new(
    agent_string     => ...,
    username         => ...,
    password         => ...,
    session_filepath => ...,
    subreddit        => ...,
    );

  $poster->send( ... );

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

sub config_defaults ( $class, $config={} ) {
	state $defaults = {
		type          => 'reddit',
		class         => __PACKAGE__,
		username      => $ENV{PERLYBOT_REDDIT_USER}          // 'perlybotng',
		password      => $ENV{PERLYBOT_REDDIT_PASS}          // undef,
		client_id     => $ENV{PERLYBOT_REDDIT_CLIENT_ID}     // undef,
		client_secret => $ENV{PERLYBOT_REDDIT_CLIENT_SECRET} // undef,
		subreddit     => $ENV{PERLYBOT_SUBREDDIT}            // '/r/perlybot',
		};

	$defaults;
	}

sub is_properly_configured ( $class, $config ) {

	1;

	}

sub new ( $class, $args ) {
	my $config = Perly::Bot::Config->get_config;

  my @missing = grep { !exists $args->{$_} }
    qw(agent_string username password client_id client_secret subreddit);

  if (@missing)
  {
    $logger->logcroak(
      "args is missing required variables (@missing) for $class");
  }

	my $snoo = Mojo::Snoo::Subreddit->new(
        name          => $args->{subreddit}     // $config->subreddit,
        client_id     => $args->{client_id}     // $config->reddit_client_id,
        client_secret => $args->{client_secret} // $config->reddit_client_secret,
        username      => $args->{username}      // $config->reddit_username,
        password      => $args->{password}      // $config->reddit_password,
		);


    my $self = bless { reddit_api => $snoo }, $class;

    $logger->logcroak("Error constructing Reddit API object: $_")
    	unless ref $self;

    return $self;
}

sub send
{
  my ( $self, $blog_post ) = @_;

  $self->{reddit_api}
    ->submit_link( $blog_post->decoded_title, $blog_post->root_url );
  sleep(2);    # throttle requests to avoid exceeding API limit
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
