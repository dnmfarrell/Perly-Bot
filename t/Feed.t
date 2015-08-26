use strict;
use warnings;
use v5.10.1;
use Test::More 0.95;
use YAML::XS 'LoadFile';

my $feeds = LoadFile('t/test_feeds.yml');

my $class = 'Perly::Bot::Feed';

use_ok($class) or BAIL_OUT( "$class did not load" );

for my $args (@$feeds)
{
  subtest $args->{url} => sub
  {
    my %args_copy = %$args;

    my $feed = new_ok( $class => [ $args ] );

    state $methods = [qw(url type date_name date_format media)];
    can_ok( $feed, @$methods );
    foreach my $method ( @$methods )
    {
      ok $feed->$method(), "$method returns something that is true (" . $feed->$method() . ")";
    }

    ok( $feed->type eq 'rss' || $feed->type eq 'atom', 'Feed type is either rss or atom (' . $feed->type . ')' );
    isa_ok $feed->media, ref [];

    like $feed->active, qr/^[01]$/, "active field is 0 or 1 (" . $feed->active . ")";
    like $feed->proxy, qr/^[01]$/, "proxy field is 0 or 1 (" . $feed->proxy . ")";
    like $feed->delay_seconds, qr/^[0-9]+$/, , "delay_seconds field is only digits (" . $feed->delay_seconds . ")";
  };
}

done_testing();
