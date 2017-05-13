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
    die "directory exists!" if $child->exists;
    $child->mkpath;
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
        # XXX - For dirs/files, get name?
        name => $name,
        dist => $dist,
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
    return $path;
  }

  # For now, metacpan only
  return $self->_resolve_dists_metacpan($dist);
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

    $self->log_verbose("\t...found", $name);
  }

  return keys %dists;
}

sub _build_dist_dir {
  my ($self, $dist) = @_;

  $self->log_verbose("Building dist dir:", $dist->{name});

  my $base = $self->_mkpath($dist->{name});

  $self->_mkpath($dist->{name}, $_) for qw(base-install passed failed);

  return $base;
}

sub _build_dist {
  my ($self, $dist) = @_;

  # XXX - Build this higher and cache for quicker smokes later?
  # XXX - Use Path::Tiny for all paths for portability
  my $ipath = $dist->{dir} . "/base-install";
  my $lpath = $ipath . ".log";

  $self->log("Building dist", $dist->{name}, "in dir", $ipath);

  my $cmd = "cpanm -L $ipath --verbose $dist->{name} > $lpath 2>&1";
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

  for my $base_dist (@{$self->dists}) {
    my %failed;
    my %passed;
    my $ipath = $base_dist->{base_install};

    $self->log("Smoking $base_dist->{name}...");

    for my $to_test (@$distributions) {
      for my $dist ($self->_resolve_dists($to_test, "quiet")) {
        $self->logx("\tTesting $dist...");

        # XXX - Write to temp file, move into place (save memory)
        my $cmd = "cpanm -l $ipath --test-only --verbose $to_test 2>&1";
        $self->log_verbose("\tRunning", $cmd);

        my $res = `$cmd`;
        my $exit = $?;

        my $report;

        if ($exit) {
          $report = path($base_dist->{dir})->child("failed")->child("$dist.txt");

          $failed{$dist}++;

          $self->log("FAIL!");
        } else {
          $report = path($base_dist->{dir})->child("passed")->child("$dist.txt");

          $passed{$dist}++;

          $self->log("PASS!");
        }

        $report->spew($res);
      }
    }

    path($base_dist->{dir})->child("failed.txt")->spew(
      join("\n", keys %failed),
    );

    path($base_dist->{dir})->child("passed.txt")->spew(
      join("\n", keys %passed),
    );

    my ($p, $f) = (0+ keys %passed, 0+ keys %failed);
    my $total = $p + $f;
    $self->log("$p out of $total distributions passed ($f failures)");
  }
}

sub log {
  my $self = shift;

  my $str = "@_";
  $str =~ s/\n\s+$/\n/;

  $str =~ s/\n+$//g;

  $self->_print($str . "\n");
}

sub logx {
  my $self = shift;

  my $str = "@_";
  $str =~ s/\n\s+$/\n/;

  $str =~ s/\n+$//g;

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

sub clean {
  my ($self) = @_;

  $self->log("Cleaning " . $self->data_dir);

  for my $child ($self->data_dir_obj->children) {
    $self->log_verbose("Removing", $child);

    $child->remove_tree({ safe => 0 });
  }
}

1;
