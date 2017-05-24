# Distribution::Smoke

Easily smoke your distribution against distributions that depend on it!

# Sample Usage

````
# Smoke a live version of your distribution against its 1st-level
# reverse-deps and some additional distributions
p5-distribution-smoke My::Module -r -a Some::Mod Another::Mod Other::*

# Smoke a local version of your module against specific mods
p5-distribution-smoke . -a Mod1 -a Mod2::Thing
````

You could also write out a config file for your module to use to smoke
it before release. For example, dist-smoke.conf:

````
-a Mod1
-a Mod2
-a Mod3
-r --depth 3
--skip Broken::Mod::.*
--skip Other::Thing
.
````

And then...

````
p5-distribution-smoke -c dist-smoke.conf
