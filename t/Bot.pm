use strict;
use warnings;
use Test::More;
use Time::Piece;
use List::Util 'any';

use_ok 'Perly::Bot', 'import module';


subtest looks_perly => sub
{
  while (my $line = <DATA>)
  {
    chomp $line;
    my ($title, $description, $is_perly) = split '===', $line;

    cmp_ok looks_perly($title, $description), '==', $is_perly, "'$title' - appears to be Perl related";
  }
};

done_testing;

sub looks_perly
{
  my ($title, $description) = @_;
  my $looks_perly = qr/\b(?:perl|perl6|cpan|cpanm|moose|metacpan|module|timtowdi|yapc?)\b/i;
  return any {  ($_ || '')  =~ /$looks_perly/ } $title, $description;
}
__DATA__
blogs.perl.org===Integrating Job::Machine into Djet....===1
Job::Machine integration===Andrew Beverly is going to talk about https://metacpan.org/pod/Dancer2::Plugin::Auth::Extensible at the Perl Dancer Conference. This talk will give an overview of what&apos;s now possible with very little code, including user registration, password resets and the management of user details....===1
Dancer2::Plugin::Auth::Extensible Presentation===For July, the CPAN Pull Request Challenge assigned me Data::Dump. Better than the pull request itself, this assignment was great to know Data::Dump, as I have never see it before. For the PR, I tried to read user complains, and...===1
CPAN PRC: July is Data::Dump===We are happy to announce the schedule for the Swiss Perl Workshop 2015. We will have the Perl 6 Hackathon starting on Thursday August, 27th, Talks on Friday, August, 28th and Workshops and Talks on Saturday, 29th. Since so many...===1
Schedule for Swiss Perl Workshop 2015 ready===We are having a hackathon at work, and Bosko, John and I have hacked together a working Perl script that executes in a Java environment (HBase)....===1
Perl5 to Java compiler is 1 month old, and we have a hackathon===I&apos;m sad to report that Nóirín Plunkett has passed away. Many in the Perl community knew them as a speaker and participant at YAPC::NA 2012 in Madison, Wisconsin, and YAPC::EU 2012 in Frankfurt, Germany, as well as other conferences including...===1
Nóirín Plunkett===The Alien::Base (AB) team has done a number of things over the past year with AB to make the installing packages more reliable. For AB based Alien developers who have created their own Alien::Libfoo this is great because they get...===0
Making Alien::Base more reliable===Sometimes you want to do something fancy with images in a completely automated way.  So for example, maybe you want to turn the image on the left into the image on the right:It turns out this is a pretty simple...===0
Masking Images with Imager===$ perlmogrify my-script.pl $ more my-script.pl.pl6 Perl::ToPerl6 is now available on CPAN. This is the final name for the previously-mentioned Perl::Mogrify tool, with the goal of being able to transliterate (not translate, subtle distinction there) working Perl5 code into...===1
Perl::ToPerl6 released to CPAN===YAPC::EU Granada has just passed 200 confirmed participants already passing two previous YAPC::EUs and there is still more than a month to go. YAPC::NA in Salt Lake City gained more than 100 additional participants in the last 30 days, but...===1
YAPC::EU - over 200 participants===I&apos;m interested in getting Convert::Binary::C into a properly maintained state once again. It has a pod test that is failing (which should be an author or release test) and a regex deprecation warning in 5.22 that will likely render it...===1
Convert::Binary::C anyone?===A hackable text editor for the 21st Century [From my blog.]...===0
A hackable text editor for the 21st Century===From last night&apos;s Sydney PM, my talk on Log4perl. In retrospect I should have named it &quot;Logging: Not the fun kind with chainsaws and axes, but the boring kind with grep and less&quot;. Check it out: Also worth sharing, from...===0
Getting modern with logging via Log4perl===I don&apos;t seem to remember any blog post here or on TPF. Has the location, time or the organizers of YAPC::NA been announced?...===1
Has YAPC::NA 2016 been announced?===Last week I promised (or threatened depending on your outlook) to talk about Alien::Base in the context of system integration and distribution packagers. Philosophy: The philosophy for Alien::Base has always been that the system library should be used when it...===1
Alien::Base: System Integrators vs. CPAN Authors===Peter Rabbitson sent me this idea: I can not think of anything qualifying as doesn&apos;t have to be a huge Perl project* However, I have an idea which unquestionably will benefit the Perl community immensely, yet has a remarkably low...===1
Grant idea - DBIx::Class re-documentation===I&apos;ve written a small performance test. And it is not bad! First perl: $ time perl misc/Java/benchmark.pl done 64000000 real 0m3.964s user 0m3.963s sys 0m0.004s And then Perl-in-Java: $ touch Test.class ; rm Test.class ; perl perlito5.pl -Isrc5/lib -I. -It...===1
a perl5 to Java compiler - first benchmark===Just a reminder that I am running a 2-days long course before YAPC::EU in Granada, Spain. In the course I am going to teach web application development using Perl Dancer and MongoDB in the back-end, and AngularJS in the front-end....===1
Web application development course before YAPC::EU===The compiler now has a small test suite. The main additions in the last 10 days were implementing global variables, better support for references, data structures, string interpolation, and a few new subroutines in the CORE namespace and operators....===1
a perl5 to Java compiler - week 3===Android Client for Lacuna Expanse: A member of The Lacuna Expanse community has built a new client for Android devices. Still in beta, but cool. [From my blog.]...===0
Android Client for Lacuna Expanse===Please join us tomorrow night, (21st July) at 6pm for our monthly meeting. Full details including location etc in this post Fliers can be downloaded here and why not like us on Facebook...===0
Tomorrow night, Sydney-PM===Alex aka ASB gave me this proposal: We (the Perl community) currently do not have a CPAN module that handles OData (cf. odata.org). There seems tob e an attempt to do it here: OData::Client But it&apos;s not finished yet, and...===1
Grant idea - OData===The Call for Papers for the Perl Dancer Conference 2015 in Vienna is now open! We are accepting presentations in a wide range of topics, for example Dancer, Modern Perl, DBIx::Class, Perl &quot;products&quot; and security. Of course, we are open...===1
Perl Dancer Conference 2015 - Call for Papers===It is part of our solar system now. Now that’s legacy. Maybe the fault is, indeed, not in our stars....===1
MakeMaker among the stars===Ever given any thought as to what the expense of catching exceptions with Try::Tiny or even eval might be? Recently a colleague was having some issues with a legacy codebase that was having requests exceed their nginx proxy timeouts. We...===0
Benchmark your failures===This week we rolled out the latest version of Alien::Base which includes a new feature and a bug fix. The most important change in this version are the two new avenues of communication that we have adopted, so I will...===0
Alien::Base 0.020 and #native===Every distribution should have a LICENSE file, that corresponds to the licensing information contained in your Makefile.PL. You can create this file from the command line by installing App::Software::License - e.g. cpanm App::Software::License. Then, just invoke the software-license command....===1
Add a LICENSE file to your distribution - it&apos;s easy!===So we have a new fresh face to our site. http://yapcbrasil2015.org Also there is still time to get a cheap plane ticket to come :). The system that we are using to make the payment only works on Brazil...===0
More about YAPC::BR===When you work on larger projects, you&apos;ll often find that database changes are hard. Multiple developers, working on the same project, changing the same tables, can be difficult. Database migration tools often (but not always), come with one or more...===1
Testing your sqitch changes===Somebody asked me: Is the Foundation mainly interested in grants to help fund work on Perl&apos;s own infrastructure -- the language itself, key modules, and other community projects -- or would it also be open to considering funding open-source applications...===1
Grants for applications (vs. Perl infrastructure)?===Merijn Brand gave me this proposal. As it&#8217;s too long for our grant ideas list, I am posting here. Currently, pack and unpack work on a string, which means that you have to move forward in the data-string yourself, if...===1
Grant idea - pack and unpack on streams===I made a list of grant idas. Nothing fancy but it&apos;s just a start. Share grant ideas. Use the ideas. Improve Perl....===1
Grant ideas===<![CDATA[Last week I formulated an interesting problem in text processing while working on one of my hobbies.&nbsp; Since I was only able to devote an hour or two here and there, it took me a few days to get the...]]>===0
Finding Common Ground ... in Both Directions===My June assignment for the CPAN Pull Request Challenge was File::LibMagic. The module had 50 FAIL reports at CPAN Testers, so I decided to start from them....===1
Test failures in File::LibMagic===The CPAN Pull Request Challenge has now been running for half a year. Hundreds of people have done pull requests on CPAN distributions. Many have fallen by the wayside, as life and other distractions caught up with them, but more...===1
You&apos;re not too late for the CPAN Pull Request Challenge===The CPAN Pull Request Challenge has now been running for half a year. Hundreds of people have done pull requests on CPAN distributions. Many have fallen by the wayside, as life and other distractions caught up with them, but more...===1
Parallels Between Anti-Sweatshop Campaigns and Consumer Advocacy for Animals===<![CDATA[In a discussion group about animal activism on Facebook, someone recently shared an article titled The Myth of the Ethical Shopper. It’s a really interesting piece about some of the problems with consumer advocacy aimed at encouraging people to buy sweatshop-free products. I highly recommend reading it. The discussion in the Facebook group was about&#8230; <a href="http://blog.urth.org/2015/08/19/parallels-between-anti-sweatshop-campaigns-and-consumer-advocacy-for-animals/">Continue reading <span class="meta-nav">&#8594;</span></a>]]>===0
