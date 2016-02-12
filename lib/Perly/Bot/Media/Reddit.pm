package Perly::Bot::Media::Reddit;
use strict;
use warnings;
use namespace::autoclean;
use Carp;
use Log::Log4perl;
use Log::Log4perl::Level;
use Try::Tiny;
use Mojo::Snoo::Subreddit;
use Role::Tiny::With;

with 'Perly::Bot::Media';

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

sub new
{
  my ( $class, $args ) = @_;

  my @missing = grep { !exists $args->{$_} }
    qw(agent_string username password client_id client_secret subreddit);

  if (@missing)
  {
    $logger->logcroak(
      "args is missing required variables (@missing) for $class");
  }
  try
  {
    bless {
      reddit_api => Mojo::Snoo::Subreddit->new(
        name          => $args->{subreddit},
        client_id     => $args->{client_id},
        client_secret => $args->{client_secret},
        username      => $args->{username},
        password      => $args->{password},
      ),
    }, $class;
  }
  catch
  {
    $logger->logcroak("Error constructing Reddit API object: $_");
  };
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
