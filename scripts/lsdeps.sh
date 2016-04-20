#!/usr/bin/bash
# List the dependencies of the given package.

set -e

. "$1" # Config file.
. "$2" # PKGBUILD.

printf 'depends = %s\n' "${depends[@]}"
printf 'makedepends = %s\n' "${makedepends[@]}"
printf 'hostdepends = %s\n' "${hostdepends[@]}"
printf 'targetdepends = %s\n' "${targetdepends[@]}"

