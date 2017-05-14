package Distribution::Smoke;
# ABSTRACT: Smoke distributions against other dists that use them

use strict;
use warnings;

use MetaCPAN::Client;
use Moo;
use MooX::Types::MooseLike::Base qw(:all);

use Path::Tiny;
use Try::Tiny;

$|++;

has data_dir => (
  is => 'rw',
  isa => Str,
  default => sub {
    '~/.p5-distribution-smoke'
  }
);

has skip_filters => (
  is => 'rw',
  isa => ArrayRef,
  default => sub { [] },
);

has name_for_reverse => (
  is => 'rw',
  isa => ArrayRef,
  default => sub { [] },
);

has test_reverse_dependencies_depth => (
  is => 'rw',
  isa => Int,
  default => 0,
);

has base_dir => (
  is => 'rw',
  isa => Str,
  default => sub { $$ }, # XXX - UUID? 
);

has data_dir_obj => (
  is => 'rw',
  lazy => 1,
  default => sub {
    my $data_dir = path(shift->data_dir);
    $data_dir->mkpath unless $data_dir->exists;
    $data_dir;
  },
);

has dist_dirs => (
  is => 'rw',
  isa => HashRef,
  default => sub { {} },
);

has dists => (
  is => 'rw',
  isa => ArrayRef,
  default => sub { [] },
);

has mcpan => (
  is => 'rw',
  default => sub { MetaCPAN::Client->new }
);

has verbose => (
  is => 'rw',
  isa => Bool,
  default => 0,
);

sub _mkpath {
  my ($self, @path) = @_;

  my $path = path(@path);

  my $p = path($self->data_dir, $self->base_dir, $path);
  $self->log_verbose("mkpath:", $p);

  return try {
    my $child = $self->data_dir_obj->child($self->base_dir, $path);
    $child->mkpath if not $child->exists;
    $child;
  } catch {
    die "Failed to create $path: $_\n",
  }
}

sub build_base_distributions {
  my ($self, $distributions) = @_;

  my @dists;

  for my $dist (@$distributions) {
    for my $name ($self->_resolve_dists($dist)) {
      push @dists, {
        name => $name,
        dist => $dist,
        file_based => ref($name) ? 1 : 0,
      };
    }
  }

  for my $dist (@dists) {
    $dist->{dir} = $self->_build_dist_dir($dist);
  }

  for my $dist (@dists) {
    $dist->{base_install} = $self->_build_dist($dist);
  }

  $self->dists(\@dists);

  return;
}

sub _resolve_dists {
  my ($self, $dist, $quiet) = @_;

  $quiet = 0 if $self->verbose;

  $self->log("Resolving distribution:", $dist) unless $quiet;

  if (my $path = $self->_resolve_dist_file($dist)) {
    $self->log("Resolved to path $path");

    return $path;
  }

  my @dists = $self->_resolve_dists_metacpan($dist);
  $self->log("Resolved to dists from metacpan: @dists");
  return @dists;
}

sub _resolve_dist_file {
  my ($self, $file) = @_;

  my $dist = path($file);

  # Looks like a path? good enough?
  if ($dist =~ /^\./ || $dist =~ /^\//) {
    unless ($dist->exists) {
      die "Cannot resolve $file, does not exist!";
    }

    return $dist;
  }

  return;
}
sub _resolve_dists_metacpan {
  my ($self, $dist) = @_;

  $self->log_verbose("Resolving distribution on metacpan:", $dist);

  $dist =~ s/::/-/g;

  my $search = $self->mcpan->distribution({ name => $dist });

  my %dists;

  while (my $found = $search->next) {
    my $name = $found->name;
    $name =~ s/-/::/g;

    $dists{$name} = 1;

    $self->log_verbose("\t... found", $name);
  }

  return keys %dists;
}

sub _skip_dist {
  my ($self, $dist) = @_;

  return unless @{ $self->skip_filters };

  for my $filter (@{ $self->skip_filters }) {
    return $filter if $dist =~ qr/$filter/;
  }
}

sub _build_dist_dir {
  my ($self, $dist) = @_;

  my $dir = $self->_dist_name_path($dist->{name});

  $self->log_verbose("Building dist dir:", $dir);

  my $base = $self->_mkpath($dir);

  $self->_mkpath($dir, $_) for qw(base-install passed failed);

  return $base;
}

sub _dist_name_path {
  my ($self, $dist) = @_;

  if (ref $dist) {
    $dist =~ s|/|-|g;
    $dist =~ s/^-//;
    $dist =~ s/-$//;
  }
  $dist =~ s/::/-/g;

  return $dist;
}

sub _build_dist {
  my ($self, $dist) = @_;

  # XXX - Build this higher and cache for quicker smokes later?
  my $ipath = $dist->{dir} . "/base-install";
  my $lpath = $ipath . ".log";

  if ( -d "$ipath/lib" ) {
    $self->log("Dist $dist->{name} already built in $ipath, proceeding to smoke.");
    return path($ipath);
  }

  $self->log("Building dist", $dist->{name}, "in dir", $ipath);

  my $cmd = "cpanm -l $ipath --verbose $dist->{name} --no-interactive > $lpath 2>&1";
  $self->log_verbose("Running", $cmd);

  my $res = `$cmd`;
  my $exit = $?;
  $res ||= "<none>";

  if ($exit) {
    die ("
Failed to install $dist->{name}, giving up.
Exit: $exit
Output: $res
You may want to look at $lpath for more info
"
    );
  }

  return path($ipath);
}

sub test_distributions {
  my ($self, $distributions) = @_;
  $distributions ||= [];

  my @to_test;

  $self->log("Resolving distribution to smoke ...");
  for my $to_test (@$distributions) {
    for my $dist ($self->_resolve_dists($to_test, "quiet")) {
      push @to_test, $dist;
    }
  }

  if ($self->test_reverse_dependencies_depth) {
    push @to_test, $self->_resolve_reverse_dependencies;
  }

  if (@{ $self->skip_filters }) {
    my @really_test;

    $self->log("Filtering out skips using @{ $self->skip_filters } ");

    for my $dist (@to_test) {
      if (my $skip = $self->_skip_dist($dist)) {
        $self->log("\t... skipping $dist because of skip rule '$skip'");

        next;
      }

      push @really_test, $dist;
    }

    @to_test = @really_test;
  }

  unless (@to_test) {
    $self->log("No dists to test with!");

    return;
  }

  $self->log("Smoking these modules: @to_test");

  my $dist_count = 0+ @{ $self->dists };
  my $test_dist_count = 0+@to_test;

  $self->log("Smoking $dist_count dists with $test_dist_count modules");

  for my $base_dist (@{$self->dists}) {
    my %failed;
    my %passed;
    my $ipath = $base_dist->{base_install};

    $self->log("Smoking $base_dist->{name} ...");

    for my $dist (@to_test) {
      my $dpath = $self->_dist_name_path($dist);

      $self->logx("\tTesting $dist ... ");
      my ($pass_report, $fail_report) = map path($base_dist->{dir})->child($_)->child("$dpath.txt"), qw( passed failed );
      my ($exit, $res, $already_done);

      if($pass_report->exists) {
        $already_done = 1;
      }
      elsif($fail_report->exists) {
        $already_done = $exit = 1;
      }
      else {
        # XXX - Write to temp file, move into place (save memory)
        my $cmd = "cpanm -l $ipath --test-only --verbose $dist --no-interactive 2>&1";
        $self->log_verbose("\tRunning", $cmd);

        $res = `$cmd`;
        $exit = $?;
      }

      $self->logx("already done ... ") if $already_done;

      my $report;

      if ($exit) {
        $report = $fail_report;

        $failed{$dist}++;

        $self->log("FAIL!");
      } else {
        $report = $pass_report;

        $passed{$dist}++;

        $self->log("PASS!");
      }

      $report->spew($res) if not $already_done;
    }

    path($base_dist->{dir})->child("failed.txt")->spew(
      join("\n", keys %failed),
    );

    path($base_dist->{dir})->child("passed.txt")->spew(
      join("\n", keys %passed),
    );

    path($base_dist->{dir})->child("combined.txt")->spew(
      sort join "\n", map( "$_\t0", keys %failed ), map( "$_\t1", keys %passed )
    );

    my ($p, $f) = (0+ keys %passed, 0+ keys %failed);
    my $total = $p + $f;
    $self->log("$p out of $total distributions passed ($f failures)");
  }
}

sub _resolve_reverse_dependencies {
  my $self = shift;

  $self->log("Checking reverse dependencies ...");

  my @work = @{$self->name_for_reverse};

  for my $base_dist (@{$self->dists}) {
    if ($base_dist->{file_based}) {
      $self->log("\tSkipping $base_dist->{name}, currently cannot determine file-based dist names!");

      next;
    }
    push @work, $base_dist->{name};
  }

  unless (@work) {
    $self->log("\tNo viable dists to search reverse deps for, skipping");

    return;
  }

  my %deps;

  my $depth = $self->test_reverse_dependencies_depth;

  $self->log("Checking reverse dependencies for @work, $depth levels deep");

  # XXX - Skip ones we already found that may point to an upper depth.
  #       For example, if we are scanning A's reverse deps, and its dep
  #       'B' has a dep 'C' that also depends directly on 'A', don't rescan
  #       'A'.
  for my $level (1..$depth) {
    $self->log_verbose("\tChecking depth level $level");

    for my $dist (@work) {
      $self->log_verbose("\t\tChecking $dist");

      my $deps = $self->mcpan->rev_deps($dist);
      my @found;

      while (my $dep = $deps->next) {
        my $dist = $dep->distribution;
        $dist =~ s/-/::/g;

        if (my $skip = $self->_skip_dist($dist)) {
          $self->log("\t\t... skipping $dist because of skip rule '$skip'");

          next;
        }

        push @found, $dist;
      }

      $self->log_verbose("\t\tFound deps: @found");

      $deps{$level}{$_} = 1 for @found;
    }

    @work = keys %{ $deps{$level} };
  }

  # XXX - Sort by level then by key for consistency
  return map { keys %$_ } values %deps;
}

sub log {
  my $self = shift;

  my $str = "@_";
  $str =~ s/\n\s+$/\n/;

  $str =~ s/\n+$//g;

  $str =~ s/\t/  /g;

  $self->_print($str . "\n");
}

sub logx {
  my $self = shift;

  my $str = "@_";
  $str =~ s/\n\s+$/\n/;

  $str =~ s/\n+$//g;

  $str =~ s/\t/  /g;

  $self->_print($str);
}

sub log_verbose {
  my $self = shift;

  return unless $self->verbose;
  return $self->log("V:", @_);
}

sub _print {
  my $self = shift;

  print "@_";
}

sub ls {
  my ($self) = @_;

  $self->log($self->data_dir);

  for my $run (reverse sort $self->data_dir_obj->children) {
    for my $dist ($run->children) {
      $self->log($dist)
    }
  }
}

sub clean {
  my ($self) = @_;

  $self->log("Cleaning " . $self->data_dir);

  for my $child ($self->data_dir_obj->children) {
    $self->log_verbose("Removing", $child);

    $child->remove_tree({ safe => 0 });
  }
}

1;
