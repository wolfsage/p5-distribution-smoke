#!/usr/bin/perl

use strictures 2;

use MetaCPAN::Client;
use Data::Dumper;

use File::Path 'make_path';

my $mod1 = shift;
my $mod2 = shift;
my $spec = shift;
my $dir  = shift;

die "Usage: $0 <module\@v1> <module\@v2> <search_spec> <report_dir>\n"
  unless $mod1 && $mod2 && $spec && $dir;

die "Directory $dir already exists\n" if -e $dir;

# simple usage
my $mcpan = MetaCPAN::Client->new();

$spec =~ s/::/-/g;

print "Searching for distributions using the name '$spec'\n";

my $m = $mcpan->distribution( { name => $spec } );

my %distros;
while ( my $thing = $m->next ) {
    my $name = $thing->name;
    $name =~ s/-/::/g;

    $distros{$name} = 1;
}

my $count = keys %distros;
print "Got $count distros\n";

my @paths;

for my $m ( $mod1, $mod2 ) {
    my $path = "$dir/$m";
    $path =~ s/\@/-/g;
    $path =~ s/::/-/g;

    push @paths, $path;

    make_path "$path/failed";
    make_path "$path/passed";

    my %pass;
    my %fail;

    print "Building $m...\n";
    my $res  = `cpanm -l $path/lib --verbose $m 2>&1`;
    my $exit = $?;
    print $res;

    if ($exit) {
        die "...failed to install $m, giving up\n";
    }

    my $current = 0;

    for my $d ( keys %distros ) {
        $current++;

        print "Building and testing $d ($current of $count)...\n";

        my $res  = `cpanm -l $path/lib --test-only --verbose $d 2>&1`;
        my $exit = $?;

        if ($exit) {
            $fail{$d} = 1;

            print "FAILED\n";

            open( my $fh, '>', "$path/failed/$d.txt" ) or die "$!\n";
            print $fh $res;
            close $fh;

        }
        else {
            $pass{$d} = 1;

            print "PASSED\n";

            open( my $fh, '>', "$path/passed/$d.txt" ) or die "$!\n";
            print $fh $res;
            close $fh;
        }
    }

    open( my $fh, '>', "$path/pass.txt" ) or die "$!\n";

    for my $k ( keys %pass ) {
        print $fh "$k\n";
    }

    close $fh;

    open( $fh, '>', "$path/fail.txt" ) or die "$!\n";

    for my $k ( keys %fail ) {
        print $fh "$k\n";
    }

    close $fh;

    my ( $p, $f ) = ( 0 + keys %pass, 0 + keys %fail );

    print "Passed with $p out of $count distibutions ($f failures)\n";
}

print "Generating report...\n";

print `./gen-report.pl @paths`;
