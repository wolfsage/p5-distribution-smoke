# p5-distribution-smoke

Distribution::Smoke - smoke various versions of a distribution against modules down the river from it

## USAGE:

Currently, it's hardcoded to test Dist::Zilla against it's plugins (this will change...)

Install version of Dist::Zilla you want to test, then:

    ./m.pl old

This will chug for a long time, writing out results to old/.

When that finishes, install the newer Dist::Zilla, then:

    ./m.pl new

When that finishes:

    ./c.pl old/ new/
    Report:
    =======
    
    Now failing:
    
    		Dist::Zilla::Plugin::ReadmeAnyFromPod
    		Dist::Zilla::Plugin::ReadmeMarkdownFromPod
    
    2 distributions continued to pass
    1 distributions continued to fail

It will output:

 * Dists that now pass
 * Dists that now fail
 * Dists that pass/fail that don't exist in the second run
 * Dists that pass/fail that don't exist in the second run
 * A count of dists that continued to pass
 * A count of dists that continued to fail
 
 
# TODO

 * Allow you to say 
  * Here's a module, smoke it against modules that directly depend on it
  * Here's a module, smoke it against modules that directly or indirectly depend on it
  * Here's a module, smoke it against a specific list
  * Use a local minicpan 
  * Automatically smoke this list of versions of a module and give me a report when that's done
  * Smoke things in parallel
  
