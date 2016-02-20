use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

package Perly::Bot::Media::Reddit;
use parent qw(Perly::Bot::Media::Base);

use namespace::autoclean;
use Data::Dumper;
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
		subreddit     => $ENV{PERLYBOT_SUBREDDIT}            // 'perlybot',
		};

	$defaults;
	}

sub is_properly_configured ( $class, $config ) {

	1;

	}

BEGIN {
	use Mojo::Snoo::Subreddit;
	package Mojo::Snoo::Subreddit;
use Data::Dumper;
	sub _submit_link_specialized ($self, $params) {
		$logger->debug( "Snoo input submit params----\n" . Dumper( $params ) );

		#$params->{url};
		$params->{sr}       = $self->name;
		$params->{api_type} = 'json';
		$params->{kind}     = 'link';
		$params->{resubmit} //= 0;
		$logger->debug( "Snoo processed submit params----\n" . Dumper( $params ) );

		my $tx = $self->_do_request('POST', '/api/submit', $params->%*);

		$logger->debug( "------------Request is\n" . $tx->req->to_string );
		$logger->debug( "------------Response is\n" . $tx->res->to_string );

		}


	sub Mojo::Snoo::Base::_do_request {
		my ($self, $method, $path, %params) = @_;

		my %headers;
		if ($self->_token_required($path)) {
			$headers{Authorization} = 'bearer ' . $self->access_token;
			}

		my $url = $self->base_url;

		$url->path("$path.json");

		if ($method eq 'GET') {
			$url->query(%params) if %params;
			return $self->agent->get($url => \%headers);
			}
		return $self->agent->post($url => \%headers, form => \%params);
		}

sub Mojo::Snoo::Base::_create_access_token {
    my $self = shift;
    # update base URL
    my %form = (
        grant_type => 'password',
        username => $self->username,
        password => $self->password,
    );
    my $access_url =
        'https://'
      . $self->client_id . ':'
      . $self->client_secret
      . '@www.reddit.com/api/v1/access_token';

$logger->debug( "Access URL: $access_url" );
    my $tx = $self->agent->post($access_url => form => \%form);


    my $res = $tx->res;
$logger->debug( "------------Request\n" . $tx->req->to_string );
$logger->debug( "------------Response\n" . $res->to_string );
    # if a problem arises, it is most likely due to given auth being incorrect
    # let the user know in this case
    if (exists($res->json->{error})) {
        my $msg =
          $res->json->{error} == 401
          ? '401 status code (Unauthorized)'
          : 'error response of ' . $res->json->{error};
        Carp::croak("Received $msg while attempting to create OAuth access token.");
    }

    # update the base URL for future endpoint calls
    $self->base_url->host('oauth.reddit.com');

    # TODO we will want to eventually keep track of token type, scope and expiration
    #      when dealing with user authentication (not just a personal script)
    return $res->json->{access_token};
}
	};

sub new ( $class, $args ) {
	my $config = Perly::Bot::Config->get_config;

	my %params = (
		name          => $args->{subreddit}     // $config->subreddit,
        client_id     => $args->{client_id}     // $config->reddit_client_id,
        client_secret => $args->{client_secret} // $config->reddit_client_secret,
        username      => $args->{username}      // $config->reddit_username,
        password      => $args->{password}      // $config->reddit_password,
		);

	my @missing = grep { ! (exists $params{$_} && defined $params{$_}) }
		qw(username password client_id client_secret name);

	if (@missing) {
		$logger->logcroak( "Missing required parameters (@missing) for $class" );
		}

	$logger->debug( "Snoo params: " . Dumper( \%params ) );

	my $snoo = Mojo::Snoo::Subreddit->new( %params );


    my $self = bless { reddit_api => $snoo }, $class;

    $logger->logcroak("Error constructing Reddit API object: $_")
    	unless ref $self;

    return $self;
	}

sub send ( $self, $blog_post ) {
	my $config = Perly::Bot::Config->get_config;
	my $res = $self->{reddit_api}->_submit_link_specialized( {
		title => $blog_post->decoded_title,
		url   => $blog_post->root_url,
		sr    => $config->subreddit
		} );
	$logger->debug( "Reddit send returns [$res]" );
	$res;
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
