package Perly::Bot::Media::JSON;
use v5.22;
use feature qw(signatures postderef);
no warnings qw(experimental::signatures experimental::postderef);
use JSON::XS qw/decode_json encode_json/;
use Log::Log4perl;

my $logger = Log::Log4perl->get_logger();

=encoding utf8

=head1 NAME

Perly::Bot::Media::JSON - prepend links to a JSON file

=head2 new ($args)

Constructor, returns a new C<Perly::Bot::Media::JSON> object.

Requires a hashref containing these key values:

  link_limit => '...',
  filepath   => '...',

=cut

sub new ( $class, $args ) {
  my @missing = grep { !( exists $args->{$_} && defined $args->{$_} ) }
    qw(filepath link_limit);

  if (@missing) {
    $logger->logcroak("Missing required parameters (@missing) for $class");
  }

  return bless $args, $class;
}

sub send ( $self, $blog_post ) {
  open my $fh_r, '<', $self->{filepath};
  my $json = do { local $/; <$fh_r>; };
  close $fh_r;

  # handle new file
  $json ||= '[]';

  my @links = @{ decode_json($json) };
  unshift @links, {
    url   => $blog_post->root_url,
    title => $blog_post->decoded_title,

    #YYYY-MM-DDT00:00:00
    posted => $blog_post->datetime->datetime,
  };

  # don't slice larger than our data or link limit
  my $limit = $self->{link_limit} > @links
    ? @links - 1
    : $self->{link_limit} - 1;
  @links = @links[ 0 .. $limit ];

  open my $fh_w, '>', $self->{filepath};
  print $fh_w encode_json( \@links );

  return 1;
}

=head1 SOURCE AVAILABILITY

This source is part of a GitHub project.

  https://github.com/dnmfarrell/Perly-Bot

=head1 AUTHOR

David Farrell C<< <dfarrell@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015, David Farrell C<< <dfarrell@cpan.org> >>. All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
