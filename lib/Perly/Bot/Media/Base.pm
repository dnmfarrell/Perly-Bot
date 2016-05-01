use v5.22;

package Perly::Bot::Media::Base;
use Carp qw(croak);

BEGIN {
  my %required_methods = map { $_, undef } qw(send);

  sub AUTOLOAD ( $self, @* ) {
    our $AUTOLOAD;
    my ( $class, $method ) = $AUTOLOAD =~ s/(.+)::(.+)//r;

    if ( exists $required_methods{$method} ) {
      croak "Method $method must be implemented in $class or its subclass";
    }
    else {
      croak "Unknown method $method";
    }
  }
}

1;
