use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

use Perly::Bot;
use Perly::Bot::Post;

use Test::More;
use Path::Tiny qw(tempfile tempdir);
use Test::Exception;
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

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
subtest dir_permissions => sub {
  my $yaml =<<YAML;
perlybot_path: 'test_setups/full_monty'
cache: {
  expiry_secs: 137,
  path: '/'
}
YAML

  throws_ok { setup_config( $yaml ) } qr/path with rwx permissions/,
    'dies on missing path with perms';
};

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
subtest missing_expiry => sub {
  my $yaml =<<YAML;
perlybot_path: 'test_setups/full_monty'
cache: {
  path: 'cache'
}
YAML

  throws_ok { setup_config( $yaml ) } qr/positive integer/,
    'dies on missing expiry_secs';
};

## # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
subtest zero_expiry => sub {
  my $yaml =<<YAML;
perlybot_path: 'test_setups/full_monty'
cache: {
  expiry_secs: 0,
  path: 't'
}
YAML
  throws_ok { setup_config( $yaml ) } qr/positive integer/,
    'dies on missing expiry_secs';
};

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
subtest negative_expiry => sub {
  my $yaml =<<YAML;
perlybot_path: 'test_setups/full_monty'
cache: {
  expiry_secs: -37,
  path: 't'
}
YAML

  throws_ok { setup_config( $yaml ) } qr/positive integer/,
    'dies on missing expiry_secs';
};

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
subtest fractional_expiry => sub {
  my $yaml =<<YAML;
perlybot_path: 'test_setups/full_monty'
cache: {
  expiry_secs: 1.1,
  path: 't'
}
YAML

  throws_ok { setup_config( $yaml ) } qr/positive integer/,
    'dies on missing expiry_secs';
};

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
subtest save => sub {
  my $yaml =<<YAML;
perlybot_path: 'test_setups/full_monty'
cache: {
  expiry_secs: 2,
  path: 't'
}
media: {
}
YAML
  my $config = eval { setup_config( $yaml ) };

  ok my $cache =$config->cache, 'constructor';
  ok $cache->save_post($post), 'save post';
  ok $cache->has_posted($post), 'cache is storing the post';

  note( "Sleeping to expire cache" );
  sleep(4); # to expire cache

  ok !$cache->has_posted($post), 'post is no longer cached';

};

sub setup_config ( $yaml ) {
  my $path = tempfile( DIR => 't', SUFFIX => '.yml' );
  $path->spew($yaml);
  Perly::Bot::Config->remake_config( $path );
  }

done_testing;
