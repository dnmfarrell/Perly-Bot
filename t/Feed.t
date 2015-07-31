use strict;
use warnings;
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
  ok keys %{$feed->media} == @{$args_copy{media_targets}};
  like $feed->active, qr/^[01]$/;
  like $feed->proxy, qr/^[01]$/;
  like $feed->delay_seconds, qr/^[0-9]+$/;
}

done_testing();
