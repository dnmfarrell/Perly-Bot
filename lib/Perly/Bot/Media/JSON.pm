package Perly::Bot::Media::JSON;
use autodie;
use strict;
use warnings;
use Mojo::JSON qw/decode_json encode_json/;

sub new {
  my ($class, $args) = @_;
  my @missing = grep { !(exists $args->{$_} && defined $args->{$_}) }
    qw(filepath link_limit);

  die "Missing required parameters (@missing) for $class" if @missing;

  return bless $args, $class;
}

sub emit {
  my ($self, $blog_post) = @_;

  my $json = '[]';
  if (-e $self->{filepath}) {
    open my $fh_r, '<', $self->{filepath};
    $json = do { local $/; <$fh_r>; };
    close $fh_r;
  }

  my @links = @{ decode_json($json) };

  if (grep { $blog_post->root_url eq $_->{url} } @links) {
    printf STDERR "already emitted %s, skipping\n", $blog_post->root_url;
    return 1;
  }

  unshift @links, {
    posted => $blog_post->datetime->datetime, #YYYY-MM-DDT00:00:00
    title  => $blog_post->decoded_title,
    url    => $blog_post->root_url,
  };

  # don't slice larger than our data or link limit
  my $limit = $self->{link_limit} > @links
    ? @links - 1
    : $self->{link_limit} - 1;
  @links = @links[ 0 .. $limit ];

  open my $fh_w, '>', $self->{filepath};
  print $fh_w encode_json(\@links), "\n";

  return 1;
}

1;
