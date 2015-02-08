#!/usr/bin/env perl
use 5.10.3;
use warnings;
use Reddit::Client;
use XML::RSS::Parser;
use XML::Atom::Client;
use HTTP::Tiny;
use HTML::Entities;
use YAML::XS qw/LoadFile DumpFile/;
use Time::Piece;
use Time::Seconds;
use Try::Tiny;
use List::Util 'any';

our $VERSION      = 0.01;
our $agent_string = "Perly_Bot/v$VERSION";

# posts must mention a Perl keyword to be considered relevant
my $looks_perly = qr/\b(?:perl|cpan|cpanminus|moose|metacpan|modules?)\b/i;

my $datetime_now = localtime;
my $ua           = HTTP::Tiny->new( agent => $agent_string );
my $rss          = XML::RSS::Parser->new;
my $feeds        = LoadFile('feeds.yml');
my $cache        = LoadFile('logs/cached_urls.yml');
refresh_cache();

open my $ERROR_LOG, '>>', 'logs/error.log' or die $!;

# get reddit creds
my $reddit_username = $ENV{REDDIT_BOT_USERNAME};
my $reddit_password = $ENV{REDDIT_BOT_PASSWORD};

log_error(
    "Env vars REDDIT_BOT_USERNAME, REDDIT_BOT_PASSWORD are not both defined")
  unless $reddit_username && $reddit_password;

for my $feed ( @{$feeds} ) {
    next unless $feed->{active};

    my $date_format = $feed->{pubDateFormat};
    my $date_name   = $feed->{pubDateName};

    my $response = $ua->get( $feed->{url} );
    if ( $response->{success} )
    {
        if ( $feed->{type} eq 'rss' )
        {
            my $posts = $rss->parse_string( $response->{content} );
            foreach my $i ( $posts->query('//item') )
            {
                try {
                    # extract the post date
                    my $datetime =
                      $i->query($date_name)->text_content =~ s/ UTC| GMT//gr;
                    my $datetime_post =
                      Time::Piece->strptime( $datetime, $date_format );

                    if ( $datetime_post > $datetime_now - ONE_DAY ) {
                        if (   $i->query('title')->text_content =~ $looks_perly
                            or $i->query('description')->text_content =~
                            $looks_perly )
                        {
                            post_reddit_link(
                                 $i->query('title')->text_content,
                                 $i->query('link')->text_content,
                            );
                        }
                    }
                }
                catch {
                    log_error("Error processing $feed->{url}. $_");
                };
            }
        }
        elsif ( $feed->{type} eq 'atom' ) {
            no strict 'refs';
            my $posts = XML::Atom::Feed->new( Stream => \$response->{content} );
            foreach my $post ( $posts->entries ) {
                try {
                    # extract the post date
                    my $datetime = $post->$date_name =~ s/ UTC| GMT//gr;
                    my $datetime_post =
                      Time::Piece->strptime( $datetime, $date_format );

                    if ( $datetime_post > $datetime_now - ONE_DAY ) {
                        if (   $post->title =~ $looks_perly
                            or $post->summary =~ $looks_perly )
                        {
                            post_reddit_link(
                                    $post->title,
                                    $post->link->href,
                            );
                        }
                    }
                }
                catch {
                    log_error("Error processing $feed->{url}. $_");
                };
            }
        }
    }
    else
    {
        log_error(
"Error requesting $feed->{url}. $response->{status} $response->{reason}"
        );
    }
}

sub log_error
{
    say $ERROR_LOG $datetime_now->datetime . "\t$_[0]";
}

sub url_is_cached
{
    my $url = shift;
    any { $url eq $_->{url} } @$cache;
}

sub cache_url
{
    my $url = shift;
    push @$cache, { url => $url, datetime => $datetime_now->datetime };
}

# sieves out stale urls
sub refresh_cache
{
    @$cache = grep {
        my $url_date =
          Time::Piece->strptime( $_->{datetime}, "%Y-%m-%dT%H:%M:%S" );
        $url_date > $datetime_now - ONE_DAY ? 1 : 0;
    } @$cache;
}

sub post_reddit_link
{
    my ($title, $url) = @_;

    return if url_is_cached($url);
    cache_url($url);

    my $session_file = 'session_data.json';
    my $reddit       = Reddit::Client->new(
        session_file => $session_file,
        user_agent   => $agent_string,
    );

    unless ( $reddit->is_logged_in ) {
        $reddit->login( $reddit_username, $reddit_password );
        $reddit->save_session();
    }

    try {
        $reddit->submit_link(
            subreddit => 'perl',
            title     => decode_entities($title),
            url       => $url
        );
    }
    catch {
        log_error("Error posting $title $url $_");
    };
    sleep(1);
}

END { DumpFile( 'cached_urls.yml', $cache ) }
