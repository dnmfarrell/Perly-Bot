use strict;
use warnings;
use Test::More;
use Perly::Bot::Feed::Post;

use_ok 'Perly::Bot::Media::Twitter', 'import module';

subtest build_tweets => sub
{
  my $mock_twitter = bless { hashtag => '#perl' }, 'Perly::Bot::Media::Twitter';
  my $mock_post = Perly::Bot::Feed::Post->new({
    delay_seconds => 10000,
    title         => 'abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz',
    url           => 'https://perltricks.com',
    proxy         => 0, # dont try to de-proxy the title!
    twitter       => 'perltricks',
  });

  my $required_components_length = 
    length (' via @' . $mock_post->{twitter}) + #via
    length ('... ') + # truncated title
    23; # url

  is $mock_twitter->_build_tweet($mock_post),
     join(' ', $mock_post->title, 'via @' . $mock_post->twitter, $mock_twitter->{hashtag}, $mock_post->url),
     'tweet string matches all inputs';

  cmp_ok length($mock_twitter->_build_tweet($mock_post)), '<=', 140, 'tweet is less within twitter limits';

  $mock_post->title('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRST');
  is $mock_twitter->_build_tweet($mock_post),
     join(' ', $mock_post->title, 'via @' . $mock_post->twitter, $mock_post->url),
     'tweet string has dropped the hashtag';

  cmp_ok length($mock_twitter->_build_tweet($mock_post)), '<=', 140, 'tweet is less within twitter limits';

  $mock_post->title('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ');
  is $mock_twitter->_build_tweet($mock_post),
     join(' ', substr($mock_post->title, 0, 140 - $required_components_length) . '...', 'via @' . $mock_post->twitter, $mock_post->url),
     'tweet string just includes the title and url';

  cmp_ok length($mock_twitter->_build_tweet($mock_post)), '<=', 140, 'tweet is less within twitter limits';

  $mock_post->title('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz');
  is $mock_twitter->_build_tweet($mock_post),
     join(' ', substr($mock_post->title, 0, 140 - $required_components_length) . '...', 'via @' . $mock_post->twitter, $mock_post->url),
     'tweet string just includes the truncated title and url';

  cmp_ok length($mock_twitter->_build_tweet($mock_post)), '<=', 140, 'tweet is less within twitter limits';
};

done_testing;
