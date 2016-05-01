use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

package Perly::Bot::Feed;
use utf8;

use Perly::Bot::UserAgent;
use namespace::autoclean;
use Scalar::Util qw(weaken);
use Time::Piece;
use Time::Seconds;
use XML::FeedPP;

use base 'Class::Accessor';
__PACKAGE__->mk_accessors(
  qw/url type date_name date_format active
    proxy media_targets delay_seconds twitter post_class/
);

my $logger = Log::Log4perl->get_logger();

=encoding utf8

=head1 NAME

Perly::Bot::Feed - represent a feed

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS

=head2 get_posts ($xml)

This method requires an xml string of the blog feed and returns an
arrayref of L<Perl::Bot::Feed::Blog> objects.

=cut

sub type_defaults ( $self ) {
  state $type_defaults = {
    rdf => {
      date_name   => 'dc:date',
      date_format => '%Y-%m-%dT%T%z',
      parser      => 'XML::FeedPP::RDF',
    },
    rss => {
      date_name   => 'pubDate',
      date_format => '%a, %d %b %Y %T %z',
      parser      => 'XML::FeedPP::RSS',
    },
    atom => {
      date_name   => 'published',
      date_format => '%Y-%m-%dT%TZ',
      parser      => 'XML::FeedPP::Atom',
    },
  };

  return $type_defaults;
}

sub defaults_for_type ( $self, $type = 'rss' ) {
  state $type_defaults = $self->type_defaults;

  unless ( exists $type_defaults->{$type} ) {
    $logger->warn("No defaults for media type [$type]!");
    return;
  }

  return $self->type_defaults->{$type};
}

sub defaults ( $class ) {
  state $defaults = {
    active        => 1,
    proxy         => 0,
    delay_seconds => 21600,
    post_class    => 'Perly::Bot::Post',
    media_targets => [
      'Perly::Bot::Media::Twitter', 'Perly::Bot::Media::Reddit',
      'Perly::Bot::Media::JSON'
    ],
  };

  $defaults;
}

sub new ( $class, $args ) {
  my %feed = ( $class->defaults->%*, $args->%* );
  my $self = bless \%feed, $class;

  unless ( defined $self->{type} ) {
    $self->{type} = 'rss';
    $logger->debug(
      "Config for $self->{url} did not specify a source type. Assuming RSS");
  }

  while ( my ( $k, $v ) = each $self->defaults_for_type( $self->{type} )->%* ) {
    next if defined $self->{$k};
    $self->{$k} = $v;
  }

  state $required = [
    qw(url type date_name date_format active media_targets proxy delay_seconds parser)
  ];
  my @missing = grep { !exists $self->{$_} } $required->@*;
  $logger->logcroak("Missing fields (@missing) for feed $self->{url}")
    if @missing;

  $logger->logcroak("Unallowed content parser $self->{parser}")
    unless $self->parser_allowed( $self->{parser} );

  unless ( $self->post_class =~ m/ \A [A-Z0-9_]+ (?: :: [A-Z0-9_]+ )+ \z /xi ) {
    $logger->logcroak(
      "Invalid post class " . $self->post_class . " for " . $self->url );
  }
  else {
    unless ( eval "require " . $self->post_class . "; 1" ) {
      $logger->logcroak(
        "Could not load post class " . $self->post_class . ": $@" );
    }
  }

  $self;
}

sub parser_allowed ( $self, $parser ) {
  return exists $self->_allowed_parsers->{$parser};
}

sub _allowed_parsers {
  state $allowed = {
    map { $_ => 1 }
      qw(
      XML::FeedPP::RSS
      XML::FeedPP::RDF
      XML::FeedPP::Atom
      ) };
  $allowed;
}

sub is_active ( $self ) {
  return 0 if ( defined $self->{active}   and !$self->{active} );
  return 0 if ( defined $self->{inactive} and $self->{inactive} );
  return 1;
}

sub trawl_blog ( $self ) {
  $logger->debug( "Trawling " . $self->url );
  my $config = Perly::Bot::Config->get_config;
  my $cache  = $config->cache;

  my $ua = Perly::Bot::UserAgent->get_user_agent;
  $logger->trace("Got UA");

  if ( my $response = $ua->get( $self->url ) ) {
    $logger->trace("Got response");
    my $content    = $response->text;
    my $blog_posts = $self->extract_posts($content);
    return $blog_posts;
  }
  else {
    $logger->logwarn( "Received nothing for feed " . $self->url );
    return [];
  }
  $logger->debug( "Trawled " . $self->url );
}

sub fetch_feed ( $self ) {
  $logger->debug("Checking $self->{url} ...");

  my $ua       = Perly::Bot::UserAgent->get_user_agent;
  my $response = $ua->get( $self->url );

  if ( my $response = $ua->get( $self->url ) ) {
    my $content = $response->text;    # decode
    $logger->debug( sprintf 'Received content length: %s', length($content) );
    $self->{content} = $content;
    return $content;
  }

  return;
}

sub extract_posts ( $self, $xml ) {
  my @posts = ();

  my @items =
    eval { $self->{parser}->new( $xml, -type => 'string' )->get_item() };

  if ($@) {
    $logger->error( "Bad XML for " . $self->url );
    $logger->debug($@);
    return [];
  }

  foreach my $i (@items) {

    # extract the post date
    my $datetime_raw   = $i->get( $self->date_name );
    my $date_format    = $self->date_format;
    my $datetime_clean = $datetime_raw;

    # time::piece does not recognise UTC as a time zone
    $datetime_clean =~ s/UTC/GMT/ if $date_format =~ /\%Z/;

    # time::piece requires timezone modifiers to not have a semicolon
    $datetime_clean =~ s/([+\-][0-9][0-9]):([0-9][0-9]$)/$1$2/
      if $date_format =~ /\%z/;

    # time::piece struggles with milliseconds
    if ( $self->date_format =~ /%ms/ ) {
      $datetime_clean =~ s/\.[0-9][0-9][0-9]//;
      $date_format =~
        s/\%ms//;    # %ms is a Perly bot convention not used by strptime
    }

    # save some useful debugging info, datetimes are weird
    if ( 0 && $logger->is_debug ) {
      $logger->debug( sprintf 'Parsing %s changed to %s using format %s',
        $datetime_raw, $datetime_clean, $date_format );
    }

    my $weak_self = $self;
    weaken($weak_self);

    my $post = eval {
      my $datetime = Time::Piece->strptime( $datetime_clean, $date_format );
      $self->post_class->new( {
        delay_seconds => $self->delay_seconds,
        description   => $i->description,
        datetime      => $datetime,
        title         => $i->title,
        url           => $i->link,
        proxy         => $self->proxy,
        twitter       => $self->twitter,
        feed => $weak_self,    # we have a reference to the feed
      } );
    };

    if ($@) {
      $logger->warn("Error creating post object: $@");
    }
    else {
      push @posts, $post;
    }
  }
  return \@posts;
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
