#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

case "${1:-}" in
    '') ./scripts/build.sh ;;
    --skip-build) ;;
    *) print -u2 'Usage: package-dmg.sh [--skip-build]'; exit 2 ;;
esac

app="$PWD/dist/FinderSearch.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
architecture=$(uname -m)
case "$architecture" in
    arm64) platform='AppleSilicon' ;;
    x86_64) platform='Intel' ;;
    *) print -u2 "Unsupported architecture: $architecture"; exit 1 ;;
esac

stage=$(mktemp -d "${TMPDIR:-/tmp}/FinderSearch-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/FinderSearch.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/Installation.txt" <<TEXT
FinderSearch $version ($platform)

Requires macOS 15 or newer and a compatible Mac.

1. Drag FinderSearch into Applications.
2. Eject this disk image and open FinderSearch from Applications.
3. To search protected folders, enable FinderSearch in System Settings >
   Privacy & Security > Full Disk Access, then quit and reopen the app.

The first launch builds the search index. Give it time before judging search.
No Xcode, Rust, or separate fsearch installation is needed.

Search and file data stay on your Mac.

Source, licenses, and bug reports:
https://github.com/gityeop/FinderSearch
TEXT

name="FinderSearch-$version-$platform.dmg"
hdiutil create -volname FinderSearch -srcfolder "$stage" -format UDZO -ov "dist/$name"
hdiutil verify "dist/$name"
(
    cd dist
    shasum -a 256 "$name" > "$name.sha256"
)
printf 'Packaged %s/dist/%s\n' "$PWD" "$name"
