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
    [],
    [ 'verbose|v', "verbose output" ],
    [ 'help|h', "print usage info and exit" ],
  ];
}

sub run {
  my ($self) = @_;

  my ($opt, $usage) = describe_options(@{$self->opt_spec});
  print($usage->text), exit if $opt->help;

  unless (@ARGV) {
    die "Missing distributions to smoke!\n";
  }

  unless ($opt->additional_module) {
    die "Missing distributions to test against our distribution\n";
  }

  my $smoker = $self->smoker;

  $smoker->verbose($opt->verbose);

  # XXX - Resolve distributions and modules-to-be-tested before
  #       building anything
  $smoker->build_base_distributions(\@ARGV);

  $smoker->test_distributions($opt->additional_module);
}

1;