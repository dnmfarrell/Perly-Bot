use strict;
use warnings;
use v5.10.1;
use Test::More 0.95;
use YAML::XS 'LoadFile';

my $feeds = LoadFile('feeds.yml');
my $allowed_social_media = qr/twitter|reddit/;
my $media = {
  'Perly::Bot::Media::Twitter' => bless({}, 'Perly::Bot::Media::Twitter'),
  'Perly::Bot::Media::Reddit'  => bless({}, 'Perly::Bot::Media::Reddit'),
};

my $class = 'Perly::Bot::Feed';

use_ok($class) or BAIL_OUT( "$class did not load" );

for my $args (@$feeds)
{
  subtest $args->{url} => sub
  {
    my %args_copy = %$args;
    $args->{media} = $media;

    my $feed = new_ok( $class => [ $args ] );

    state $methods = [qw(url type date_name date_format media)];
    foreach my $method ( @$methods )
    {
    ok $feed->$method(), "$method returns something that is true"
    }

    TODO: {
    # This test might not make sense if you want to configure the media
    # source differently in the config.
    local $TODO = 'The Perltricks setting has only one target';
    is scalar keys %{$feed->media}, scalar @{$args_copy{media_targets}},
    "There are the right number of media targets for " . $feed->url;
    }

    like $feed->active, qr/^[01]$/, "active field is 0 or 1";
    like $feed->proxy, qr/^[01]$/, "proxy field is 0 or 1";
    like $feed->delay_seconds, qr/^[0-9]+$/, , "delay_seconds field is only digits";
  };
}

done_testing();
