package Perly::Bot::Config;
use strict;
use warnings;
use Path::Tiny;
use YAML::XS;

my $self;
sub instance {
  my ($class, %args) = @_;
  unless ($self) {
    $self = bless { %args }, $class;
    $self->{config} = $self->load_config;
  }
  return $self;
}

sub config_filepath {
  my $self = shift;
  return "config/$self->{tier}.yml";
}

sub load_config {
  my $file = $self->config_filepath;
  # use canonpath for cross platform support
  return YAML::XS::LoadFile( Path::Tiny->new($file)->canonpath );
}

sub feeds {
  my $self = shift;
  return $self->{config}{feeds};
}

sub media {
  my $self = shift;
  return $self->{config}{media};
}

sub agent_string {
  my $self = shift;
  return $self->{config}{agent_string};
}

sub age_threshold_secs {
  my $self = shift;
  return $self->{config}{should_emit}{age_threshold_secs};
}

sub feed_data {
  my ($self) = @_;
  my $filepath = $self->feeds->{filepath};
  return YAML::XS::LoadFile( Path::Tiny->new($filepath)->canonpath );
}

1;
