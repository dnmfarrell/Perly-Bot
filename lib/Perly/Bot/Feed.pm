package Perly::Bot::Feed;
use strict;
use warnings;
use v5.10;
use utf8;

use Carp;
use Log::Log4perl;
use Log::Log4perl::Level;
use Perly::Bot::Feed::Post;
use Role::Tiny;
use Time::Piece;
use Time::Seconds;
use XML::Atom::Client;
use XML::RSS::Parser;

use base 'Class::Accessor';
Perly::Bot::Feed->mk_accessors(qw/url type date_name date_format active proxy media delay_seconds twitter/);

my $logger = Log::Log4perl->get_logger();

=encoding utf8

=head1 NAME

Perly::Bot::Feed - represent a feed

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS

=head2 get_posts ($xml)

This method requires an xml string of the blog feed and returns an arrayref of L<Perl::Bot::Feed::Blog> objects.

=cut

sub get_posts
{
  my ($self, $xml) = @_;

  $logger->logcroak( 'Error get_posts() requires an $xml argument' ) unless $xml;

  my @posts = ();

  if ( $self->type eq 'rss' )
  {
      my $rss = XML::RSS::Parser->new;
      my $parsed_xml = $rss->parse_string( $xml );
      foreach my $i ( $parsed_xml->query('//item') )
      {
        # extract the post date
        my $datetime_raw = $i->query($self->date_name)->text_content =~ s/ UTC| GMT//gr;
        my $datetime = Time::Piece->strptime($datetime_raw, $self->date_format);

        push @posts, Perly::Bot::Feed::Post->new({
          delay_seconds => $self->delay_seconds,
          description   => $i->query('description')->text_content,
          datetime      => $datetime,
          title         => $i->query('title')->text_content,
          url           => $i->query('link')->text_content,
          proxy         => $self->proxy,
          twitter       => $self->twitter,
        });
      }
  }
  elsif ( $self->type eq 'atom' )
  {
    # accessors are generated from the available tags in the atom feed
    # the tags can have different names, so we store the tag name in feeds.yml
    no strict 'refs';
    my $items = XML::Atom::Feed->new( Stream => \$xml);
    foreach my $i ( $items->entries )
    {
      # extract the post date
      my $datetime_element_name = $self->date_name;
      my $datetime_raw = $i->$datetime_element_name =~ s/ UTC| GMT//gr;
      my $datetime = Time::Piece->strptime( $datetime_raw, $self->date_format );

        push @posts, Perly::Bot::Feed::Post->new({
          description => $i->summary,
          datetime    => $datetime,
          #title       => encode('utf8', decode('utf8', $i->title)),
          title       => $i->title,
          url         => $i->link->href,
          proxy       => $self->proxy,
        });
    }
  }
  return \@posts
}

=head1 TO DO

=head1 SEE ALSO

=head1 SOURCE AVAILABILITY

This source is part of a GitHub project.

	https://github.com/dnmfarrell/Perly-Bot

=head1 AUTHOR

David Farrell C<< <sillymoos@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015, David Farrell C<< <sillymoos@cpan.org> >>. All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

