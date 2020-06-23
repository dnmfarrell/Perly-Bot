use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);

package Perly::Bot::Post;

use Perly::Bot::UserAgent;
use Perly::Bot::Config;
use HTML::Entities;
use List::Util qw(sum any);
use Time::Piece;
use Log::Log4perl;

use base 'Class::Accessor';
__PACKAGE__->mk_accessors(
  qw/url title description domain datetime content_regex twitter feed/);

=encoding utf8

=head1 NAME

Perly::Bot::Post - process a social media post

=head1 FUNCTIONS

=head2 clean_url

Removes the query component of the url. This is to reduce the risk of posting duplicate urls with different query parameters.

=cut

sub clean_url ($self, $url = undef) {
  my $uri       = Mojo::URL->new(($url || $self->url));
  my $clean_url = $uri->scheme . '://' . $uri->host . $uri->path;
  printf STDERR "Cleaned URL to [%s]\n", $clean_url;
  return $clean_url;
}

sub domain ($self) { $self->{domain} //= Mojo::URL->new($self->root_url)->host }


=head2 root_url

Returns the clean url, it will follow the url and return the ultimate location the URL redirects to. Sets the post's raw content.

=cut

sub root_url ($self) {
  # if we've already retrieved the root url, don't pull it again
  return $self->{_root_url} if $self->{_root_url};

  my ($request, $response) = Perly::Bot::UserAgent->instance->get($self->url);
  if ($response)
  {
    my $url = $request->url->to_abs();
    printf STDERR "URL is [%s]\n", $url;

    # set the post content
    $self->{raw_content} = $response->body;

    $self->{_root_url} = $self->clean_url($url);
    return $self->{_root_url};
  }
}

=head2 raw_content

Returns the raw HTML of the post

=cut

sub raw_content ($self) {
  return $self->{raw_content} if exists $self->{raw_content};
  $self->root_url(); # fetch the article and set the content
  return $self->{raw_content} or die 'root_url() did not set the post content';
}

=head2 extract_body_text

Extracts text from the raw body HTML

=cut

sub extract_body_text ($self, $content = $self->raw_content){
  my $regex = $self->get_extraction_regex;
  my $paragraphs = join "\n", $content =~ /$regex/g;
  die sprintf 'failed to extract text from [%s]', $self->domain unless $paragraphs;
  $paragraphs =~ s/<\/?.+?>//g;
  return decode_entities($paragraphs);
}

sub get_extraction_regex ($self, $domain = $self->domain) {
  state $domain_regexes = {
    'blogs.perl.org'                  => qr/<div class="entry-body">(.+?)<!-- .entry-body -->/si,
    'blog.plover.com'                 => qr/class="mainsection"(.+?)<\/table>/si,
    'rjbs.manxome.org'                => qr/<div class='body markup:md'>(.+?)<div id='footer'>/si,
    'perltricks.com'                  => qr/<article>(.+?)<\/article>/si,
    'blog.geekuni.com'                => qr/<div class='post-header'>(.+?)<div class='post-footer'>/si,
    'www.learning-perl.com'           => qr/<div class="entry">(.+?)<!-- END entry -->/si,
    'www.masteringperl.org'           => qr/<div class="entry">(.+?)<!-- END entry -->/si,
    'www.intermediateperl.com'        => qr/<div class="entry">(.+?)<!-- END entry -->/si,
    'www.effectiveperlprogramming.com'=> qr/<div class="entry">(.+?)<!-- END entry -->/si,
    'techblog.babyl.ca'               => qr/<div class="blog_entry">(.+?)<div id="disqus_thread">/si,
    'www.dagolden.com'                => qr/<div class="entry-content">(.+?)<!-- .entry-content -->/si,
    'p6weekly.wordpress.com'          => qr/<div class="entry-content">(.+?)<!-- .entry-content -->/si,
    '6guts.wordpress.com'             => qr/<div class="entry-content">(.+?)<!-- .entry-content -->/si,
    'perlhacks.com'                   => qr/<div class="entry-content">(.+?)<!-- .entry-content -->/si,
    'blog.urth.com'                   => qr/<div class="entry-content(.+?)<!-- .entry-content -->/si,
    'perlmaven.com'                   => qr/<div role="main" id="main">(.+?)<div class="prev-next">/si,
    'leonerds-code.blogspot.com'      => qr/articleBody(.+?)<div style='clear: both;'>/si,
    'default'                         => qr/<p>(.+?)<\/p>/si,
  };
  my $key = exists $domain_regexes->{$domain} ? $domain : 'default';
  $domain_regexes->{$key};
}


sub body ($self, $content = undef) {
  $self->{body} //= $self->extract_body_text($content)
}

=head2 decoded_title

Returns the blog post title decoded from html using L<HTML::Entities>. This is required because some titles have HTML encoded characters in them.

=cut

sub decoded_title ($self) { decode_entities($self->title) }

=head2 should_emit

The logic to decide if a blog post should be emitted or not. This is:

- if the post is recent
- not too new to exceed the delay (to allow authors to post their own links)
- it looks Perl-related and is not already posted

Feel free to subclass and override this logic with your own needs for a particular
post type!

=cut

sub _content_exclusion_methods ($self) {
  qw(
    has_short_title
    has_no_perlybot_tag
    no_byterock
 );
}

sub _content_metric_methods ($self) {
  qw(body_looks_perly
     body_word_count
 );
}

sub fails_by_policy ($post) {
  my $time_now = gmtime;

  printf STDERR "Fresh calculaton post age %d threshold %d\n", 
    $time_now - $post->datetime, $post->age_threshold_secs;

  my $policy = {
    stale => ($time_now - $post->datetime > $post->age_threshold_secs)
    ? 1
    : 0,
    embargo => 0,
    cached => 0,
  };

  $post->{policy} = $policy;
  $post->{policy}{_sum} = sum(values %$policy);

  return $post->{policy}{_sum};
}

sub threshold ($self) { 2 }

sub should_emit ($post) {
  printf STDERR "Evaluating %s for emittal\n", $post->title;

  # these checks are for non-content things we configured
  return 0 if $post->fails_by_policy;

  # these checks are for things that absolutely exclude the post
  # no matter what else is going on
  my @killed = grep { $post->$_() } $post->_content_exclusion_methods;
  $post->{killed} = \@killed;
  if (@killed) {
    printf STDERR "Failed content exclusion checks: [%s]. %s\n",
      join(',',@killed), $post->title;

    return 0;
  }

  my %points = map { $_, $post->$_($post->raw_content) || 0 } $post->_content_metric_methods;
  $post->{points} = \%points;

  my $points = sum(values %points);

  return 1 if $points >= $post->threshold;

  return 0;
}

=head2 age_threshold_secs

Returns the configured age_threshold_secs value. You can override this
to decide a value based on anything you like.

=cut

sub age_threshold_secs { Perly::Bot::Config->instance->age_threshold_secs }

=head2 has_short_title

Returns true if the post has a title shorter than 6 characters.

=cut

sub has_short_title ($post) { length ($post->title || '') < 6 }

=head2 looks_perly(POST)

Returns true if the post looks like it's about Perl. Since it's a method
you can override this in specialized post types.

=cut

sub looks_perly ($post, $text) {
  state $looks_perly =
    qr/\b(?:perl|cpan|moose|metacpan|module|subroutine|timtowdi|yapc|\:\:)\b/i;

  $text =~ $looks_perly;
}

sub body_looks_perly ($self, $content = undef) { $self->looks_perly($self->body($content)) }

sub has_no_perlybot_tag ($self) { $self->raw_content =~ /no-perly-bot/i }

# this user writes a lot of posts we don't want to share
sub no_byterock ($self) { $self->raw_content =~ /byterock/i }

sub word_count ($self, $content) {
  my @words = split /\s+/, $content;
  return scalar @words;
}
sub body_word_count ($self, $content = undef) { $self->word_count($self->body($content)) > 150 }

sub clone ($self) {
  state $storable = require Storable;
  my $clone = Storable::dclone($self);
}

1;
