package Perly::Bot::Media::Reddit;
use v5.22;
use warnings;
no warnings qw(experimental::signatures experimental::postderef);
use feature qw(signatures postderef);
use Mojo::Snoo::Subreddit;
use Carp 'croak';

my $logger = Log::Log4perl->get_logger();

=encoding utf8

=head1 NAME

Perly::Bot::Media::Reddit - Post to Reddit

=head1 SYNOPSIS

  use Perly::Bot::Media::Reddit;

  my $poster = Perly::Bot::Media::Reddit->new(
    subreddit     => ...,
    client_id     => ...,
    client_secret => ...,
    username      => ...,
    password      => ...,
  );

  $poster->send( ... );

=cut

sub new ( $class, $args ) {
  my %params = (
    name          => $args->{subreddit},
    client_id     => $args->{client_id},
    client_secret => $args->{client_secret},
    username      => $args->{username},
    password      => $args->{password},
  );

  my @missing = grep { !( exists $params{$_} && defined $params{$_} ) }
    qw(username password client_id client_secret name);

  if (@missing) {
    $logger->logcroak("Missing required parameters (@missing) for $class");
  }

  my $self = eval {
    bless { reddit_api => Mojo::Snoo::Subreddit->new(%params) }, $class;
  };

  if ( $@ || !ref $self ) {
    $logger->logcroak("Error constructing $class $@");
  }

  return $self;
}

sub send ( $self, $blog_post ) {
  my $res =
    $self->{reddit_api}
    ->submit_link( $blog_post->decoded_title, $blog_post->root_url,
    sub { $_[0] },
    );
  my $json   = $res->json->{json};
  my $data   = $json->{data};
  my $errors = $json->{errors};

  if ( ref $errors eq 'ARRAY' && @$errors ) {

    # errors are returned as an array of arrays
    croak( sprintf 'Reddit returned errors: %s',
      join ', ', map { join ' ', @$_ } @$errors );
  }
  return $data;
}

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
