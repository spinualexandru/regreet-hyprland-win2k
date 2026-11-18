#!/bin/bash
# Build the patched ReGreet that install.sh installs.
#
#   ./build.sh            clone upstream ReGreet 0.5.0 into src-regreet/ (if it isn't there yet),
#                         apply regreet-0.5.0-classic-logon.patch and run cargo build --release
#   ./build.sh --clean    delete src-regreet/ entirely (it can always be recreated with ./build.sh)
#
# Run it as yourself, not as root; then run: sudo ./install.sh
#
# src-regreet/ is a throwaway working copy: the patch file is the source of truth. If you edit
# the code in src-regreet/, regenerate the patch so the changes aren't lost on the next clean:
#   (cd src-regreet && git diff) > regreet-0.5.0-classic-logon.patch
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
src=$here/src-regreet
patch=$here/regreet-0.5.0-classic-logon.patch
repo=https://github.com/rharish101/ReGreet
tag=0.5.0
commit=290e6f8d65b7034c5b63bc950a20bcf8277ebe5f   # what tag 0.5.0 pointed to when the patch was made

if [[ $EUID -eq 0 ]]; then
    echo "Run this as yourself, not as root (root-owned build files get in the way later)." >&2
    exit 1
fi

if [[ ${1:-} == --clean ]]; then
    rm -rf "$src"
    echo "Removed $src"
    exit 0
fi

if [[ ! -d $src ]]; then
    git clone --quiet --depth 1 --branch "$tag" "$repo" "$src"
fi

actual=$(git -C "$src" rev-parse HEAD)
if [[ $actual != "$commit" ]]; then
    echo "$src is at $actual, expected $commit (ReGreet $tag)." >&2
    echo "Remove it (./build.sh --clean) and run ./build.sh again." >&2
    exit 1
fi

if git -C "$src" apply --reverse --check "$patch" 2>/dev/null; then
    echo "Patch already applied."
elif git -C "$src" apply --check "$patch" 2>/dev/null; then
    git -C "$src" apply "$patch"
    echo "Patch applied."
else
    echo "The patch neither applies cleanly nor is already applied: src-regreet/ has other edits." >&2
    echo "Save them with: (cd $src && git diff) > my-changes.patch" >&2
    echo "then ./build.sh --clean and ./build.sh." >&2
    exit 1
fi

(cd "$src" && cargo build --release --locked)

echo "Built $src/target/release/regreet. Install it with: sudo $here/install.sh"
