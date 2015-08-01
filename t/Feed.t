use strict;
use warnings;
use v5.10.1;
use Test::More;
use YAML::XS 'LoadFile';
use Perly::Bot::Media::Twitter;
use Perly::Bot::Media::Reddit;

my $feeds = LoadFile('feeds.yml');
my $allowed_social_media = qr/twitter|reddit/;
my $media = {
  'Perly::Bot::Media::Twitter' => bless({}, 'Perly::Bot::Media::Twitter'),
  'Perly::Bot::Media::Reddit'  => bless({}, 'Perly::Bot::Media::Reddit'),
};
use_ok('Perly::Bot::Feed');

for my $args (@$feeds)
{
  my %args_copy = %$args;
  $args->{media} = $media;

  ok my $feed = Perly::Bot::Feed->new($args);
  ok $feed->url;
  ok $feed->type;
  ok $feed->date_name;
  ok $feed->date_format;
  ok $feed->media;
  is scalar keys %{$feed->media}, scalar @{$args_copy{media_targets}};
  like $feed->active, qr/^[01]$/;
  like $feed->proxy, qr/^[01]$/;
  like $feed->delay_seconds, qr/^[0-9]+$/;
}

if ($ENV{PERLY_BOT_UTF8_TEST})
{
  my $feed = Perly::Bot::Feed->new({
    url           => 'http://blogs.perl.org/atom.xml',
    type          => 'atom',
    date_name     => 'published',
    date_format   => '%Y-%m-%dT%H:%M:%SZ',
    active        => 1,
    media_targets => ['Perly::Bot::Media::Twitter', 'Perly::Bot::Media::Reddit'],
    proxy         => 0,
    delay_seconds => 21600,
  });
  my $response = do { local(@ARGV, $/) = 't/atom.xml';<> };

  use Encode qw/encode decode/;
  my $decoded_response = decode('UTF-8', $response);
  $decoded_response = encode('UTF-8', $decoded_response);

  my $posts = $feed->get_posts($decoded_response);
  for (@$posts)
  {
    say $_->title;
  }
}

done_testing();
