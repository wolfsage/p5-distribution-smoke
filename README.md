# p5-distribution-smoke

Distribution::Smoke - smoke various versions of a distribution against modules down the river from it

## USAGE:

     ./dist-smoke.pl <dist@ver1> <dist@ver2> <search_spec> <output_dir>

For example:

      ./dist-smoke.pl Dist::Zilla@5.047 Dist::Zilla@6.000 'Dist::Zilla::Plugin::Readme*' results 

This will chug for a couple of minutes and be fairly verbose, then it will generate a report that looks like:

     Generating report...
     Report:
     =======
     
	     Now failing:
     
		    Dist::Zilla::Plugin::ReadmeMarkdownFromPod
		    Dist::Zilla::Plugin::ReadmeAnyFromPod
     
     
     2 distributions continued to pass
     1 distributions continued to fail

It will output (for anything that has any information):

 * Dists that now pass
 * Dists that now fail
 * Dists that pass/fail that don't exist in the second run
 * Dists that pass/fail that don't exist in the second run
 * A count of dists that continued to pass
 * A count of dists that continued to fail

## What it does:

 * Creates the requested build directory
 * Installs the first version of the distribution requested
 * Installs all matching distributions to <search_spec> from MetaCPAN::Client
 * Generates some reports and meta files
 * Installs the second version of the distribution requested
 * Repeates the previous two steps
 * Generates a report comparing pass/fail statistics

## Generated directory:

For the example above:

     ./results
     ./results/Dist-Zilla-5.047
     ./results/Dist-Zilla-5.047/passed     - cpanm reports, one per distribution
     ./results/Dist-Zilla-5.047/failed     - cpanm reports, one per distribution    
     ./results/Dist-Zilla-5.047/lib        - cpanm local lib (-l option)
     ./results/Dist-Zilla-5.047/pass.txt   - list of distributions that passed
     ./results/Dist-Zilla-5.047/fail.txt   - list of distributions that failed
     ./results/Dist-Zilla-6.000
     ./results/Dist-Zilla-6.000/passed     - ...
     ./results/Dist-Zilla-6.000/failed     - ...
     ./results/Dist-Zilla-6.000/lib        - ...
     ./results/Dist-Zilla-6.000/pass.txt   - ...
     ./results/Dist-Zilla-60000/fail.txt   - ....

# TODO

 * Allow you to say 
  * Here's a module, smoke it against modules that directly depend on it
  * Here's a module, smoke it against modules that directly or indirectly depend on it
  * Here's a module, smoke it against a specific list
  * Use a local minicpan 
  * Automatically smoke this list of versions of a module and give me a report when that's done
  * Smoke things in parallel
  
