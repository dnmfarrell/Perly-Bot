package Perly::Bot::UserAgent;
use strict;
use warnings;

use parent qw(Mojo::UserAgent);

my $self;
sub instance {
  my ($class, $args) = @_;
  $args //= {};
  return $self if defined $self;
  $self = $class->new($args);
}

sub new {
  my ($class, $args) = @_;
  $args //= {};

  my $config = Perly::Bot::Config->instance;
  $args->{name} //= $config->agent_string;

  my $ua = Mojo::UserAgent->new;
  $ua->request_timeout(30)->connect_timeout(30)->max_redirects(3)
    ->transactor->name('Perly_Bot');

  my $obj = bless $ua, $class;

  # tolerate invalid certs and slow websites
  $obj->insecure(1);
  $obj->connect_timeout(5);
  $obj->request_timeout(5);
}

sub get {
  my ($self, $url) = @_;
  my $tx = $self->SUPER::get($url);
  my $res = $tx->result;
  unless ($res->is_success) {
    warn sprintf
        "Could not fetch [%s] Got a [%d]\n------\n%s\n------\n%s\n------\n",
      $url, $res->code, $tx->req->to_string, $res->to_string;
    return;
  }

  if (wantarray) {
    ($tx->req, $res, $tx);
  }
  else {
    $tx->res;
  }
}

1;
