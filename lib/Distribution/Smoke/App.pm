package Distribution::Smoke::App;

use strictures 2;

use Distribution::Smoke;

use Moo;
use MooX::Types::MooseLike::Base ':all';

use Path::Tiny;
use Try::Tiny;

use Getopt::Long::Descriptive;

has opt_spec => is => 'ro', builder => '_build_opt_spec';
has smoker   => is => 'rw', default => sub { Distribution::Smoke->new };

sub _build_opt_spec {
    return [
        '%c %o <thing-to-smoke>',
        [ 'additional-module|a=s@', "modules to smoke" ],
        [ 'clean',      "clean all previous runs from the data dir" ],
        [ 'config|c=s', "config file to parse default options from" ],
        [ 'ls|l',       "list all previous runs in the data dir" ],
        [ 'reverse-dependencies|r', "test reverse dependencies" ],
        [
            'name-for-reverse|n=s@',
            "dist names to add when searching for reverse dependencies",
            { implies => 'reverse_dependencies' },
        ],
        [
            'base-dir|b=s',
            "name of the sub dir to run the set of smokes in, defaults to \$\$"
        ],
        [
            'depth|d=i',
            "go <n> levels deep when looking for reverse deps."
              . " (default 1. Implies reverse_dependencies)",
            { implies => 'reverse_dependencies' },
        ],
        [ 'skip|s=s@', "regular expressions of modules to not smoke" ],
        [],
        [ 'verbose|v!', "verbose output" ],
        [ 'help|h',     "print usage info and exit" ],
    ];
}

sub parse_opts {
    my ($self) = @_;
    my ( $opt, $usage ) = describe_options( @{ $self->opt_spec } );
    print( $usage->text ), exit if $opt->help;
    return $opt, $usage;
}

sub run {
    my ($self) = @_;

    my @orig_argv = @ARGV;

    my ( $opt, $usage ) = $self->parse_opts;
    if ( $opt->config ) {
        ## Config options should be loaded first, and command line options override
        ( $opt, $usage ) = $self->rebuild_opts_with_config(
            { config => $opt->config, orig_argv => \@orig_argv } );
    }

    $ENV{PERL_MM_USE_DEFAULT} = $ENV{AUTOMATED_TESTING} =
      $ENV{PERL_MM_NONINTERACTIVE} = 1;
    open STDIN, '<',
      File::Spec->devnull;    # won't somebody think of the children?!

    my $smoker = $self->smoker;
    $smoker->base_dir( $opt->base_dir ) if $opt->base_dir;
    $smoker->verbose( $opt->verbose );

    if ( $opt->clean ) {
        $smoker->clean;
        exit;
    }

    if ( $opt->ls ) {
        $smoker->ls;
        exit;
    }

    $smoker->test_reverse_dependencies_depth( $opt->depth || 1 )
      if $opt->reverse_dependencies;

    die "Missing distributions to smoke!\n"
      if not @ARGV;
    die "Missing distributions to test against our distribution\n"
      if !$opt->additional_module or !$opt->reverse_dependencies;

    $smoker->skip_filters( $opt->skip                 || [] );
    $smoker->name_for_reverse( $opt->name_for_reverse || [] );

    # XXX - Resolve distributions and modules-to-be-tested before
    #       building anything
    $smoker->build_base_distributions( \@ARGV );

    $smoker->test_distributions( $opt->additional_module );
    return;
}

sub rebuild_opts_with_config {
    my ( $self, $arg ) = @_;

    # Transform multilines into single config
    my $config = path( $arg->{config} );

    die "Failed to open $config: File does not exist\n"
      if not $config->exists;
    die "Failed to open $config: File is a directory\n"
      if not $config->is_file;

    my $config_data = $config->slurp;
    $config_data =~ s/\n/ /g;

    @ARGV = ( split( /\s+/, $config_data ), @{ $arg->{orig_argv} } );

    return $self->parse_opts;
}

1;
