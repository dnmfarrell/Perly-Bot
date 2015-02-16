use strict;
use warnings;
use Test::More;
use YAML::XS 'LoadFile';

use_ok('Perly::Bot');

my $cache = LoadFile('logs/cached_urls.yml');

for my $entry (@$cache)
{
  ok Perly::Bot::is_cached($entry->{url});
}

done_testing();
