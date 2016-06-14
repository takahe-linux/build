# README #

takahe-build - helper scripts for takahe-linux.

# New build script #

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
- No distinction between host and target dependencies.

Things that the new system does not fix (yet):

- No signal handling. (v0.1.6)
- No support for test scripts. (v0.1.6)
- Trivial (comments, whitespace, etc) fixes still cause rebuilds. (v0.1.6)
- Package directories should not be identified by name, but by a file which
  contains the required information. (v0.1.7)
- No build profiling (used disk space, memory, etc). (v0.1.7)
- No "check for updates" script support. (v0.1.7)
- Asynchronous and networked builds. (v0.1.7)
- No 'activity monitor' (should be relatively easy to fix, prereq for async
  builds). (v0.1.7)
- No build profiling (used disk space, etc). (v0.1.7)
- No cross-compile support in makepkg (via libmakepkg?). (v0.3.0)
- A new "branch" for something still requires a complete rebuild, or "dirtying"
  some shared branch. (v???)

Things that have regressed:

- I no longer have a test script (run\_test.sh) for starting a QEMU VM with the
  current image. (v0.1.6)
- Requires *even more* RAM, due to the chroot location, which is not currently
  configurable. Requires build profiling. (v0.1.7)
- The config files contain information that the build system should provide,
  for instance --sysroot=/sysroot in cflags.

# Usage #

To generate/update the packages:
 ./rebuild.sh _configdir_

To build an image suitable for using in QEMU, see mksysimage and popsysimage.

