#!/usr/bin/perl

use strict;
use warnings;

use MetaCPAN::Client;
use Data::Dumper;

my $dir = shift;

die "Usage: $0 <report_dir>\n" unless $dir;

mkdir "$dir" or die "failed to mkdir $dir: $!\n";
mkdir "$dir/build" or die "failed to mkdir $dir/build: $!\n";
mkdir "$dir/failed" or die "failed to mkdir $dir/failed: $!\n";
mkdir "$dir/passed" or die "failed to mkdir $dir/passed: $!\n";

# simple usage
my $mcpan  = MetaCPAN::Client->new();

my $m = $mcpan->distribution({ name => 'Dist-Zilla-Plugin' });

my %distros;
while (my $thing = $m->next) {
  my $name = $thing->name;
  $name =~ s/-/::/g;

  # Alien::Subversion, FTN
  next if $name =~ /Subversion/i;

  $distros{$name} = 1;
}

my $c = keys %distros;
print "Got $c distros\n";

my %pass;
my %fail;

for my $d (keys %distros) {
  print "Building and testing $d...\n";

  my $res = `cpanm -l $dir/lib --test-only --verbose $d 2>&1`;
  my $exit = $?;

  if ($exit) {
    $fail{$d} = 1;

    print "FAILED\n";

    open(my $fh, '>', "$dir/failed/$d.txt");
    print $fh $res;
    close $fh;

  } else {
    $pass{$d} = 1;

    print "PASSED\n";

    open(my $fh, '>', "$dir/passed/$d.txt");
    print $fh $res;
    close $fh;
  }
}

open(my $fh, '>', "$dir/pass.txt");

for my $k (keys %pass) {
  print $fh "$k\n";
}

close $fh;

open ($fh, '>', "$dir/fail.txt");

for my $k (keys %fail) {
  print $fh "$k\n";
}

close $fh;

my ($p, $f) = (0+ keys %pass, 0+ keys %fail);

print "Passed with $p out of $c distibutions ($f failures)\n";
