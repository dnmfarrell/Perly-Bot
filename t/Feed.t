use strict;
use warnings;
use v5.10.1;
use Test::More '0.95';
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
  subtest $args->{url} => sub
  {
    my %args_copy = %$args;
    $args->{media} = $media;

    ok my $feed = Perly::Bot::Feed->new($args);
    ok $feed->url;
    ok $feed->type;
    ok $feed->date_name;
    ok $feed->date_format;
    ok $feed->media;

    TODO: {
    # This test might not make sense if you want to configure the media
    # source differently in the config.
    local $TODO = 'The Perltricks setting has one target';
    is scalar keys %{$feed->media}, scalar @{$args_copy{media_targets}},
    "There are the right number of media targets for " . $feed->url;
    }

    like $feed->active, qr/^[01]$/;
    like $feed->proxy, qr/^[01]$/;
    like $feed->delay_seconds, qr/^[0-9]+$/;
  };
}

done_testing();
