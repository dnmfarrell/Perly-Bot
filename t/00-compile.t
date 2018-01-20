use Test::More;

my @classes = qw(
  Perly::Bot
  Perly::Bot::Cache
  Perly::Bot::Config
  Perly::Bot::Feed
  Perly::Bot::Media::JSON
  Perly::Bot::Media::Reddit
  Perly::Bot::Media::Twitter
  Perly::Bot::Post
  Perly::Bot::UserAgent
  );

foreach my $class ( @classes )
{
  BAIL_OUT( "$class does not compile" ) unless use_ok( $class );
}

done_testing();
