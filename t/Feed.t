use strict;
use warnings;
use Test::More;
use YAML::XS 'LoadFile';

my $feeds = LoadFile('feeds.yml');
my $allowed_social_media = qr/twitter|reddit/;

use_ok('Perly::Bot::Feed');

for (@$feeds)
{
  ok my $feed = Perly::Bot::Feed->new($_);
  ok $feed->url;
  ok $feed->type;
  ok $feed->date_name;
  ok $feed->date_format;
  ok $feed->social_media_targets;
  like $feed->active, qr/^[01]$/;
  like $feed->proxy, qr/^[01]$/;
  like $feed->delay_seconds, qr/^[0-9]+$/;
  like ($_, $allowed_social_media) for @{$feed->social_media_targets};
}

done_testing();
