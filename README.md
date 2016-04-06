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
- Some hardcoded variables.
- Asynchronous and networked builds.
- Native cross-compile support in makepkg (via libmakepkg).
- "Target system" support.
- No 'activity monitor' (should be relatively easy to fix, prereq for async
  builds).
- No support for test scripts.
- No support for 'native' builds.
- Trivial (comments, whitespace, etc) fixes still cause rebuilds.

Things that have regressed:

- System image creation.
- Packages databases are redownloaded each time a package is built.

## Notes ##

In each config directory, we store:

- Build information.
- Source tarballs.
- Built packages.
- 'src' (targets, PKGBUILDs)
- Config file.

Do we need any global configs?
Do we need seperate directories for different architectured build machines?
What gets extracted from external files?

## ##

TODO: Fill this out.
