package Perly::Bot;
use strict;
use warnings;
use Path::Tiny;
use Perly::Bot::Config;
use Perly::Bot::Feed;
use Perly::Bot::Media::JSON;

sub new {
  my ($class) = @_;
  return bless {}, $class;
}

sub run {
  my $self = shift;
  my $total_emitted = 0;
  my $feeds         = 0;
  my $config        = Perly::Bot::Config->instance;

  binmode STDOUT, ':utf8';
  binmode STDERR, ':utf8';

  for my $feed_data ( $config->feed_data->@* ) {
    $feeds++;
    my $feed = Perly::Bot::Feed->new($feed_data);
    printf STDERR "Processing feed [%s]\n", $feed->url;
    my $posts = $feed->trawl_blog;
    printf STDERR "Found %d posts in [%s]\n", scalar @$posts, $feed->url;

    my $emitted = 0;
    for my $post ( $posts->@* ) {
      my $emit = eval { $post->should_emit };
      if ($@) {
        warn $@;
      }
      next unless !$@ && $emit;
      $emitted += $self->emit($feed, $post);
    }

    $total_emitted += $emitted;
    printf STDERR "Emitted [%d] posts for [%s]\n", $emitted, $feed->url;
  }
  printf STDERR "Emitted [%d] posts in [%d] feeds\n", $total_emitted, $feeds;
}

sub emit {
  my ($self, $feed, $post) = @_;
  printf "Emitting [%s]\n", $post->title;

  my $config  = Perly::Bot::Config->instance;
  my @errors  = ();
  my $emitted = 0;

  for my $media_target ( $feed->media_targets->@* ) {
    printf "Media target is [%s]\n", $media_target;
    my $media = $media_target->new($config->media->{$media_target});
    my $res = eval { $media->emit($post) };

    if ( $@ || !$res ) {
      my $error = sprintf 'Could not send post! [%s] %s', $post->title, $@;
      warn "$error\n";
      push @errors, $error;
    }
    else {
      $emitted = 1;
    }
  }
  printf "[%d] errors for [%s]\n", scalar @errors, $post->title;
  return $emitted;
}

1;
