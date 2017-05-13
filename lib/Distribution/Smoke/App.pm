package Distribution::Smoke::App;

use strict;
use warnings;

use Distribution::Smoke;

use Moo;
use MooX::Types::MooseLike::Base qw(:all);

use Path::Tiny;
use Try::Tiny;

use Getopt::Long::Descriptive;

has opt_spec => (
  is => 'ro',
  builder => '_build_opt_spec',
);

has smoker => (
  is => 'rw',
  default => sub { Distribution::Smoke->new; },
);

sub _build_opt_spec {
  return [
    '%c %o <thing-to-smoke>',
    [ 'additional-module|a=s@', "module to smoke" ],
    [ 'clean', "clean all previous runs from the data dir" ],
    [ 'config|c=s', "Config file to parse default options from" ],
    [ 'ls|l',  "list all previous runs in the data dir" ],
    [ 'reverse-dependencies|r', "Test reverse dependencies" ],
    [ 'depth|d=i', "Go <n> levels deep when looking for reverse deps. (default 1. Implies reverse_dependencies)",
      { default => 1, implies => 'reverse_dependencies' },
    ],
    [],
    [ 'verbose|v!', "verbose output" ],
    [ 'help|h', "print usage info and exit" ],
  ];
}

sub parse_opts {
  my $self = shift;

  my ($opt, $usage) = describe_options(@{$self->opt_spec});
  print($usage->text), exit if $opt->help;
  return ($opt, $usage);
}

sub run {
  my ($self) = @_;

  my @orig_argv = @ARGV;

  my ($opt, $usage) = $self->parse_opts;

  if ($opt->config) {
    # Config options should be loaded first, and command line
    # options override
    ($opt, $usage) = $self->rebuild_opts_with_config({
      config    => $opt->config,
      orig_argv => \@orig_argv,
    });
  }

  my $smoker = $self->smoker;
  $smoker->verbose($opt->verbose);

  if ($opt->clean) {
    $smoker->clean;

    exit;
  }

  if ($opt->ls) {
    $smoker->ls;

    exit;
  }

  if ($opt->reverse_dependencies) {
    $smoker->test_reverse_dependencies_depth($opt->depth);
  }

  unless (@ARGV) {
    die "Missing distributions to smoke!\n";
  }

  unless ($opt->additional_module || $opt->reverse_dependencies) {
    die "Missing distributions to test against our distribution\n";
  }

  # XXX - Resolve distributions and modules-to-be-tested before
  #       building anything
  $smoker->build_base_distributions(\@ARGV);

  $smoker->test_distributions($opt->additional_module);
}

sub rebuild_opts_with_config {
  my ($self, $arg) = @_;

  # Transform multilines into single config
  my $config = path($arg->{config});

  unless ($config->exists) {
    die "Failed to open $config: File does not exist\n";
  }

  unless ($config->is_file) {
    die "Failed to open $config: File is a directory\n";
  }

  my $config_data = $config->slurp;

  $config_data =~ s/\n/ /g;

  @ARGV = (
    split(/\s+/, $config_data),
    @{ $arg->{orig_argv} }
  );

  return $self->parse_opts;
}

1;
