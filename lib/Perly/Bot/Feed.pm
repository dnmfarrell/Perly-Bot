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
    proxy media_targets post_class/
);

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

sub type_defaults ($self) {
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

sub defaults_for_type ($self, $type = 'rss') {
  state $type_defaults = $self->type_defaults;

  unless (exists $type_defaults->{$type}) {
    warn "No defaults for media type [$type]!\n";
    return;
  }

  return $self->type_defaults->{$type};
}

sub defaults ($class) {
  state $defaults = {
    active        => 1,
    proxy         => 0,
    post_class    => 'Perly::Bot::Post',
    media_targets => [
      'Perly::Bot::Media::JSON',
    ],
  };

  $defaults;
}

sub new ($class, $args) {
  my %feed = ($class->defaults->%*, $args->%*);
  my $self = bless \%feed, $class;

  unless (defined $self->{type}) {
    $self->{type} = 'rss';
  }

  while (my ($k, $v) = each $self->defaults_for_type($self->{type})->%*) {
    next if defined $self->{$k};
    $self->{$k} = $v;
  }

  state $required = [
    qw(url type date_name date_format active media_targets proxy parser)
  ];
  my @missing = grep { !exists $self->{$_} } $required->@*;
  die "Missing fields (@missing) for feed $self->{url}" if @missing;

  die "Unallowed content parser $self->{parser}"
    unless $self->parser_allowed($self->{parser});

  unless ($self->post_class =~ m/ \A [A-Z0-9_]+ (?: :: [A-Z0-9_]+)+ \z /xi) {
    die "Invalid post class " . $self->post_class . " for " . $self->url;
  }
  else {
    unless (eval "require " . $self->post_class . "; 1") {
      die "Could not load post class " . $self->post_class . ": $@";
    }
  }

  $self;
}

sub parser_allowed ($self, $parser) {
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

sub is_active ($self) {
  return 0 if (defined $self->{active}   and !$self->{active});
  return 0 if (defined $self->{inactive} and $self->{inactive});
  return 1;
}

sub trawl_blog ($self) {
  warn "Trawling " . $self->url . "\n";

  my $ua = Perly::Bot::UserAgent->instance;

  if (my $response = $ua->get($self->url)) {
    my $content    = $response->text;
    my $blog_posts = $self->extract_posts($content);
    return $blog_posts;
  }
  else {
    warn "Received nothing for feed " . $self->url . "\n";
    return [];
  }
}

sub fetch_feed ($self) {
  my $ua       = Perly::Bot::UserAgent->instance;
  my $response = $ua->get($self->url);

  if (my $response = $ua->get($self->url)) {
    my $content = $response->text;    # decode
    printf STDERR "Received content length: %s\n", length $content;
    $self->{content} = $content;
    return $content;
  }

  return;
}

sub extract_posts ($self, $xml) {
  my @posts = ();

  my @items =
    eval { $self->{parser}->new($xml, -type => 'string')->get_item() };

  if ($@) {
    warn  "Bad XML for " . $self->url . ": $@\n";
    return [];
  }

  foreach my $i (@items) {

    # extract the post date
    my $datetime_raw   = $i->get($self->date_name);
    my $date_format    = $self->date_format;
    my $datetime_clean = $datetime_raw;

    # time::piece does not recognise UTC as a time zone
    $datetime_clean =~ s/UTC/GMT/ if $date_format =~ /\%Z/;

    # time::piece requires timezone modifiers to not have a semicolon
    $datetime_clean =~ s/([+\-][0-9][0-9]):([0-9][0-9]$)/$1$2/
      if $date_format =~ /\%z/;

    # trim whitespace
    $datetime_clean =~ s/\A\s+|\s+\Z//gm;

    # time::piece struggles with milliseconds
    if ($self->date_format =~ /%ms/) {
      $datetime_clean =~ s/\.[0-9][0-9][0-9]//;
      $date_format =~
        s/\%ms//;    # %ms is a Perly bot convention not used by strptime
    }

    my $weak_self = $self;
    weaken($weak_self);

    my $post = eval {
      my $datetime = Time::Piece->strptime($datetime_clean, $date_format);
      $self->post_class->new({
        description   => $i->description,
        datetime      => $datetime,
        proxy         => $self->proxy,
        title         => $i->title,
        epoch         => $datetime->epoch,
        url           => $i->link,
      });
    };

    if ($@) {
      warn "Error creating post object: $@";
    }
    else {
      push @posts, $post;
    }
  }
  return \@posts;
}

1;
