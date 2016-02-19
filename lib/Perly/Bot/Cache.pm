use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

use open qw(:std :utf8);

package Perly::Bot::Cache;

use namespace::autoclean;
use CHI;
use File::Path qw/make_path/;
use Perly::Bot::CommonSetup;

my $logger = Log::Log4perl->get_logger();

=encoding utf8

=head1 NAME

Perly::Bot::Cache - store what Perlybot has already done

=head1 SYNOPSIS

=head1 DESCRIPTION

This is a thin wrapper around C<CHI::File>, used to store URLs of
blog posts emitted by C<Perly::Bot> (to avoid emitting the same
blog posts over and over).

=head1 METHODS

=head2 new ($cache_path, $expires_secs)

Constructor, returns a new Perly::Bot::Cache::Object. Requires
an executable, writable, readable directory path as an argument
and the number of seconds to store a cache entry for.

=cut

sub new ( $class ) {
  my $config = Perly::Bot::Config->get_config;
  my $cache_path = $config->cache_path;
  my $expires_secs = $config->cache_expiry;

  make_path($cache_path)
    unless !$cache_path
    || ( $cache_path && -d $cache_path );

  $logger->logdie('new() requires a directory path with rwx permissions')
    unless $cache_path
    && -x $cache_path
    && -w $cache_path
    && -r $cache_path;

  $logger->logdie(
    'new() requires a positive integer for the expiry duration of entries')
    unless $expires_secs
    && $expires_secs =~ /^[0-9]+$/
    && $expires_secs > 0;

  my $cache = CHI->new(
    driver     => 'File',
    root_dir   => $cache_path,
    expires_in => $expires_secs,
  );

  bless { chi => $cache }, $class;
}

=head2 has_posted ($post)

Checks the cache to see if the C<Perly::Bot::Feed::Post> has already been posted.

=cut

sub has_posted ( $self, $post ) {
  $logger->logdie(
    'has_posted() requires a Perly::Bot::Feed::Post object as an argument')
    unless $post && $post->isa('Perly::Bot::Feed::Post');

  $self->{chi}->is_valid( $post->root_url );
}

=head2 save_post ($post)

Saves the C<Perly::Bot::Feed::Post> object in the cache.

=cut

sub save_post ( $self, $post ) {
  $logger->logdie(
    'save_post() requires a Perly::Bot::Feed::Post object as an argument')
    unless $post && $post->isa('Perly::Bot::Feed::Post');

  $self->{chi}->set( $post->root_url, $post );
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
