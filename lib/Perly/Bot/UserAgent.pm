use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);
use Log::Log4perl;

package Perly::Bot::UserAgent;

use parent qw(Mojo::UserAgent);

my $logger = Log::Log4perl->get_logger();

sub get_user_agent ( $class, $args = {} ) {
  state $self;
  return $self if defined $self;

  $self = $class->new($args);
}

sub new ( $class, $args = {} ) {
  my $config = Perly::Bot::Config->get_config;
  $args->{name} //= $config->agent_string;

  my $ua = Mojo::UserAgent->new;
  $ua->request_timeout(30)->connect_timeout(30)->max_redirects(3)
    ->transactor->name( 'Perly_Bot' );

  bless $ua, $class;
}

sub get ( $self, $url ) {
  my $tx = $self->SUPER::get($url);
  unless ( $tx->success ) {
    $logger->error(
      sprintf
        "Could not fetch [%s] Got a [%d]\n------\n%s\n------\n%s\n------\n",
      $url, $tx->res->code, $tx->req->to_string, $tx->res->to_string );
    return;
  }

  if (wantarray) {
    ( $tx->req, $tx->res, $tx );
  }
  else {
    $tx->res;
  }
}
