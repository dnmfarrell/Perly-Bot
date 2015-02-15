package Perly::Bot::Feed;
use strict;
use warnings;
use Time::Piece;
use Carp;
use Perly::Bot::Feed::Post;
use XML::RSS::Parser;
use XML::Atom::Client;

use base 'Class::Accessor';
Perly::Bot::Feed->mk_accessors(qw/url type date_name date_format active proxy social_media_targets/);

=head2 get_posts ($xml)

This method requires an xml string of the blog feed and returns an arrayref of L<Perl::Bot::Feed::Blog> objects.

=cut

sub get_posts
{
  my ($self, $xml) = @_;

  croak 'Error get_posts() requires an $xml argument' unless $xml;

  my @posts = ();

  if ( $self->type eq 'rss' )
  {
      my $rss = XML::RSS::Parser->new;
      my $parsed_xml = $rss->parse_string( $xml );
      foreach my $i ( $parsed_xml->query('//item') )
      {
        # extract the post date
        my $datetime_raw = $i->query($self->date_name)->text_content =~ s/ UTC| GMT//gr;
        my $datetime =
          Time::Piece->strptime( $datetime_raw, $self->date_format );

        push @posts, Perly::Bot::Feed::Post->new({
          description => $i->query('description')->text_content,
          datetime => $datetime,
          title => $i->query('title')->text_content,
          url   => $i->query('link')->text_content,
          proxy => $self->proxy,
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
          datetime => $datetime,
          title => $i->title,
          url   => $i->link->href,
          proxy => $self->proxy,
        });
    }
  }
  return \@posts
}

1;

