# README

takahe-build - helper scripts for takahe-linux.

# Planned Features

- No "check for updates" script support. (v0.1.8)
  This could be implemented by checking upstream for a more recent version,
  either by probing or parsing an updates page, by using
  [repology](https://repology.org/api/v1) for versions, or by a combination of
  the above methods.
- ccache support. (v0.1.8)
- No build profiling (used disk space, memory, etc). (v0.2.0) (#profile)
- No 'activity monitor' (should be relatively easy to fix, prereq for async
  builds). (v0.2.0)
- Asynchronous and networked builds. (v0.2.1)
- Add support for a 
  [config.site](https://www.gnu.org/software/autoconf/manual/autoconf-2.63/html_node/Site-Defaults.html)
  file, which should help speed up builds through letting me manually cache
  results, and ensure that cross-compiled packages work as expected (see the
  bash PKGBUILD for examples). (v0.2.2)
- No cross-compile support in makepkg (via libmakepkg?). (v0.3.0)
- A new "branch" for something still requires a complete rebuild, or "dirtying"
  some shared branch. (v???)

Things that have regressed compared to the original script:

- Requires *even more* RAM, due to the chroot location, which is not currently
  configurable. (v0.2.3) (depends on #profile)

# Usage

To generate/update the packages:
 ./rebuild.sh _configdir_

To build an image suitable for using in QEMU, see mksysimage and popsysimage.
To create a bootable CDROM, see mkiso.
To create a fs and boot it in QEMU using the supplied kernel:
 ./boot.sh _configdir_

The scripts assume that you are running an up-to-date Arch Linux system, with
base-devel installed. Additionally, you must have installed 'fakechroot'.
