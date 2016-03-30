use Test::More;

my @classes = qw(
  Perly::Bot
  Perly::Bot::Feed
  Perly::Bot::Cache
  Perly::Bot::Media
  Perly::Bot::Media::Twitter
  Perly::Bot::Media::Reddit
  Perly::Bot::Post
  );

foreach my $class ( @classes )
{
  BAIL_OUT( "$class does not compile" ) unless use_ok( $class );
}

done_testing();
