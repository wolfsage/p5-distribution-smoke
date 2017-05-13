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
    [ 'ls|l',  "list all previous runs in the data dir" ],
    [ 'reverse-dependencies|r', "Test reverse dependencies" ],
    [ 'depth|d=i', "Go <n> levels deep when looking for reverse deps. (default 1. Implies reverse_dependencies)",
      { default => 1, implies => 'reverse_dependencies' },
    ],
    [],
    [ 'verbose|v', "verbose output" ],
    [ 'help|h', "print usage info and exit" ],
  ];
}

sub run {
  my ($self) = @_;

  my ($opt, $usage) = describe_options(@{$self->opt_spec});
  print($usage->text), exit if $opt->help;

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

1;
