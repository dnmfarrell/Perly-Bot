#!/usr/bin/perl
use Test::More;
use Log::Log4perl;
use Perly::Bot::Config;

my $base_path = 't/Bot/Post/';

my @test_files = (
  { domain => 'blogs.perl.org', filename => 'i-write-comment.html', word_count => '', looks_perly => 1 },
  { domain => 'blogs.perl.org', filename => 'Interlude 2, in which I write more about the release pipeline | Max Maischein [blogs.perl.org].html', word_count => 1, looks_perly => 1 },
  { domain => 'blogs.perl.org', filename => 'My Workflow for Building Distros | Ron Savage [blogs.perl.org].html', word_count => '', looks_perly => '' },
  { domain => 'blogs.perl.org', filename => 'The Secret Life of Acronyms | Ron Savage [blogs.perl.org].html', word_count => 1, looks_perly => 1 },
  { domain => 'blog.plover.com', filename => 'The Universe of Discourse : How to recover lost files added to Git but not committed.html', word_count => 1, looks_perly => 1 },
  { domain => 'perltricks.com', filename => 'Fixing a sluggish Linux after suspend-resume.html', word_count => 1, looks_perly => '' },
  { domain => 'perltricks.com', filename => 'Perl Jam VI: April Trolls.html', word_count => 1, looks_perly => 1 },
  { domain => 'blog.afoolishmanifesto.com', filename => 'Python: Taking the Good with the Bad - fREW Schmidt\'s Foolish Manifesto.html', word_count => 1, looks_perly => 1 },
  { domain => 'www.dagolden.com', filename => 'Stand up and be counted: Annual MongoDB Developer Survey | David Golden.html', word_count => '', looks_perly => 1 },
  { domain => 'www.dagolden.com', filename => 'When RFCs attack: HTTP::Tiny is getting stricter | David Golden.html', word_count => 1, looks_perly => 1 },
  { domain => 'blog.geekuni.com', filename => 'The Geek Refectory - Food for Thought: Interview - Perl’s Pumpking Ricardo Signes.html', word_count => 1, looks_perly => 1 },
  { domain => 'rjbs.manxome.org', filename => 'Dist::Zilla v6 is here.html', word_count => 1, looks_perly => 1 },
  { domain => 'techblog.babyl.ca', filename => 'groom', word_count => 1, looks_perly => '' },
  { domain => 'techblog.babyl.ca', filename => 'taskwarrior', word_count => 1, looks_perly => 1 },
  { domain => 'www.nu42.com', filename => 'macgyver-html-email-perl.html', word_count => 1, looks_perly => 1 },
  { domain => 'neilb.org', filename => 'qah2016-retrospective.html', word_count => 1, looks_perly => 1 },
  { domain => 'perlhacks.com', filename => 'index.html', word_count => 1, looks_perly => 1 },
  { domain => 'blog.urth.org', filename => 'index.html.1', word_count => 1, looks_perly => '' },
  { domain => '6guts.wordpress.com', filename => 'index.html.2', word_count => 1, looks_perly => 1 },
  { domain => 'p6weekly.wordpress.com', filename => 'index.html.3', word_count => 1, looks_perly => 1 },
  { domain => '6guts.wordpress.com', filename => 'index.html.3', word_count => 1, looks_perly => 1 },
  { domain => 'szabgab.com', filename => 'switching-gears.html', word_count => 1, looks_perly => 1 },
  { domain => 'szabgab.com', filename => 'youtube-channel-at-1000-subscribers.html', word_count => '', looks_perly => 1 },
);

BEGIN { use_ok 'Perly::Bot::Post' }

for my $file (@test_files) {
  open my $html_fh, '<', $base_path . $file->{filename};
  my $html = do { local $/;<$html_fh> };

  ok $html, "Opened $file->{filename}";
  ok my $post = Perly::Bot::Post->new($file), 'create new Post object';
  ok my $content = $post->extract_body_text($html), 'get post content';
  ok $post->body($html), 'get post body';
  ok $post->body(), 'get post body - no args';
  is $post->looks_perly($content), $file->{looks_perly}, 'content looks perly';
  is $post->body_word_count($html), $file->{word_count}, 'content has enough words - ' 
    . $post->word_count($content);
}

done_testing;
