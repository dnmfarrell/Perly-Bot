use Test::More;
use strict;
use warnings;
use Path::Tiny 'tempdir';
use Test::Exception;
use Perly::Bot::Feed::Post;
use Time::Piece;

# setup test data
my $cache_path = tempdir;
my $post = Perly::Bot::Post->new({
  delay_seconds => 6000,
  description   => 'A short description of this post',
  datetime      => gmtime,
  title         => 'A test post',
  url           => 'http://someblog.com/posts/123',
  proxy         => 0,
});

use_ok 'Perly::Bot::Cache', 'load module';

# check fails
dies_ok { Perly::Bot::Cache->new() } 'Missing args';
dies_ok { Perly::Bot::Cache->new('/') } 'Dir but wrong permissions';
dies_ok { Perly::Bot::Cache->new($cache_path) } 'Missing expiry seconds';
dies_ok { Perly::Bot::Cache->new($cache_path, 0) } 'Expiry seconds must be greater than zero';
dies_ok { Perly::Bot::Cache->new($cache_path, -10) } 'Expiry seconds must be greater the zero';
dies_ok { Perly::Bot::Cache->new($cache_path, 1.1) } 'Expriry seconds must be an integer';

ok my $cache = Perly::Bot::Cache->new($cache_path->canonpath, 2), 'constructor';
ok $cache->save_post($post), 'save post';
ok $cache->has_posted($post), 'cache is storing the post';

sleep(2); # to expire cache

ok !$cache->has_posted($post), 'post is no longer cached';

done_testing;
