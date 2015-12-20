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
use XML::FeedPP;
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

sub new
{
  state $type_defaults = {
    rss => {
    date_name   => 'pubDate',
    date_format => '%a, %d %b %Y %H:%M:%S %z',
    parser      => 'XML::RSS::Parser',
      },
    atom => {
    date_name   => 'published',
    date_format => '%Y-%m-%dT%H:%M:%SZ',
    parser      => 'XML::FeedPP',
      },
  };

  state $defaults = {
    active        => 1,
    proxy         => 0,
    media         => ['Perly::Bot::Media::Twitter', 'Perly::Bot::Media::Reddit'],
    delay_seconds => 21600,
  };

  my ($class, $args) = @_;

  unless( defined $args->{type} )
  {
    $args->{type} = 'rss';
    $logger->debug( "Config for $args->{url} did not specify a source type. Assuming RSS" );
  }

  my %config = (
    %{ $type_defaults->{$args->{type}} },
    %$defaults,
    %$args
    );

  state $required = [qw(url type date_name date_format active media proxy delay_seconds parser)];
  my @missing = grep { ! exists $config{$_} } @$required;
  $logger->logcroak( "Missing fields (@missing) in call to $class" )
    if @missing;

  $logger->logcroak( "Unallowed content parser $config{parser}" )
    unless exists $class->_allowed_parsers->{ $config{parser} };

  bless \%config, $class;
}

sub _allowed_parsers
{
  state $allowed = {
    map { $_ => 1 } qw(
     XML::RSS::Parser
     XML::FeedPP
     ) };
  $allowed;
}

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
    my @items = XML::FeedPP::Atom->new($xml, -type => 'string')->get_item();
    foreach my $i ( @items )
    {
      # extract the post date
      my $datetime_raw = $i->get( $self->date_name ) =~ s/ UTC| GMT//gr;
      my $datetime = Time::Piece->strptime( $datetime_raw, $self->date_format );

        push @posts, Perly::Bot::Feed::Post->new({
          description => $i->summary,
          datetime    => $datetime,
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

David Farrell C<< <dfarrell@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015, David Farrell C<< <dfarrell@cpan.org> >>. All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

