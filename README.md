# README #

takahe-build

TODO: Add...


## Architecture ##

Previously, I used a script to create a new system image.
Unfortunately, that script had a few... issues:

- Hardcoded variables.
- Build consistency issues.
- Lacking in cleanup/teardown support.
- Relied on date and time for identifying old targets.
- Didn't use a chroot (we now use fakechroot).
- Didn't differentiate between 'build' and 'runtime' dependencies.
- Relied on some hacks.
- Could not detect changes in other files, eg the config.
- Didn't have native logging.
- Required root.
- Couldn't handle working with different git branches.

Things that the new system does not fix (yet):

- Massive number of TODO's.
- No cross-compile support in makepkg (via libmakepkg).
- No support for 'native' builds.
- No support for test scripts.
- Trivial (comments, whitespace, etc) fixes still cause rebuilds.
- Asynchronous and networked builds.
- No 'activity monitor' (should be relatively easy to fix, prereq for async
  builds).
- No build profiling (used disk space, etc). 

Things that have regressed:

- System image creation.
- Requires *even more* RAM, due to the chroot location, which is not currently
  configurable. Requires build profiling.
- Some local configuration stuff does not get carried across, eg PACKAGER, and
  "-jx".

## Notes ##

In each config directory, we store:

- Build information.
- Source tarballs.
- Built packages.
- 'src' (targets, PKGBUILDs)
- Config file.

Do we need any global configs?
Do we need separate directories for different architectured build machines?
What gets extracted from external files?

The config file is assumed to contain a few variables:

- 'triplet':    Target triplet
- 'id':         Config id
- 'arch':       Target arch
- 'cflags':     Target cflags
- 'ldflags':    Target ldflags


# Usage #

TODO: Fill this out.


