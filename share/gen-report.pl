#!/usr/bin/perl

use strictures 2;

use Data::Dumper;

my $dir1 = shift;
my $dir2 = shift;

my %pass1;
my %fail1;

my %pass2;
my %fail2;

%pass1 = fillin("$dir1/pass.txt");
%fail1 = fillin("$dir1/fail.txt");

%pass2 = fillin("$dir2/pass.txt");
%fail2 = fillin("$dir2/fail.txt");

my %pass_lost;
my %fail_lost;

my %pass_new;
my %fail_new;

my %pass_now;
my %fail_now;

my $passed;
my $failed;

for my $p ( keys %pass1 ) {
    if ( delete $fail2{$p} ) {
        $fail_now{$p} = 1;
    }
    elsif ( !delete $pass2{$p} ) {
        $pass_lost{$p} = 1;
    }
    else {
        $passed++;
    }
}

for my $f ( keys %fail1 ) {
    if ( delete $pass2{$f} ) {
        $pass_now{$f} = 1;
    }
    elsif ( !delete $fail2{$f} ) {
        $fail_lost{$f} = 1;
    }
    else {
        $failed++;
    }
}

%pass_new = %pass2;
%fail_new = %fail2;

print "Report:\n";
print "=======";

if (%pass_now) {
    print "\n\n\tNow passing:\n\n";

    for my $k ( keys %pass_now ) {
        print "\t\t$k\n";
    }
}

if (%fail_now) {
    print "\n\n\tNow failing:\n\n";

    for my $k ( keys %fail_now ) {
        print "\t\t$k\n";
    }
}

if (%pass_new) {
    print "\n\n\tNew passes? (not in original run at all\n\n";

    for my $k ( keys %pass_new ) {
        print "\t\t$k\n";
    }
}

if (%fail_new) {
    print "\n\n\tNew fails? (not in original run at all\n\n";

    for my $k ( keys %fail_new ) {
        print "\t\t$k\n";
    }
}

if (%pass_lost) {
    print "\n\n\tLost passes? (not in new run at all\n\n";

    for my $k ( keys %pass_lost ) {
        print "\t\t$k\n";
    }
}

if (%fail_lost) {
    print "\n\n\tLost fails? (not in new run at all\n\n";

    for my $k ( keys %pass_lost ) {
        print "\t\t$k\n";
    }
}

print "\n\n$passed distributions continued to pass\n";
print "$failed distributions continued to fail\n";

sub fillin {
    my $file = shift;

    my @res;

    open( my $fh, '<', $file ) or die "Failed to topen $file: $!\n";
    while (<$fh>) {
        chomp;
        next unless /\w/;

        push @res, $_;
    }

    return map { $_ => 1 } @res;
}
