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

- Package directories should not be identified by name, but by a file which
  contains the required information. (v0.1.7) (#pkgdir)
- No "check for updates" script support. (v0.1.7)
- We don't support groups. (v0.1.7)
- No build profiling (used disk space, memory, etc). (v0.1.8) (#profile)
- No 'activity monitor' (should be relatively easy to fix, prereq for async
  builds). (v0.1.8)
- Asynchronous and networked builds. (v0.1.8)
- Add support for a 
  [config.site](https://www.gnu.org/software/autoconf/manual/autoconf-2.63/html_node/Site-Defaults.html)
  file, which should help speed up builds through letting me manually cache
  results, and ensure that cross-compiled packages work as expected (see the
  bash PKGBUILD for examples). (v0.1.9)
- No cross-compile support in makepkg (via libmakepkg?). (v0.3.0)
- A new "branch" for something still requires a complete rebuild, or "dirtying"
  some shared branch. (v???)

Things that have regressed:

- Requires *even more* RAM, due to the chroot location, which is not currently
  configurable. (v0.1.8) (depends on #profile)

# Usage #

To generate/update the packages:
 ./rebuild.sh _configdir_

To build an image suitable for using in QEMU, see mksysimage and popsysimage.
To create a fs and boot it in QEMU using the supplied kernel:
 ./boot.sh _configdir_

The scripts assume that you are running an up-to-date Arch Linux system, with
base-devel installed. Additionally, you must have installed 'fakechroot'.
