#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

: "${APPLE_SIGN_IDENTITY:?Set APPLE_SIGN_IDENTITY to a Developer ID Application identity}"
: "${APPLE_NOTARY_PROFILE:?Set APPLE_NOTARY_PROFILE to a notarytool keychain profile}"

./scripts/build.sh
app="$PWD/dist/FinderSearch.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
architecture=$(uname -m)
case "$architecture" in
    arm64) platform='AppleSilicon' ;;
    x86_64) platform='Intel' ;;
    *) print -u2 "Unsupported architecture: $architecture"; exit 1 ;;
esac

codesign --force --options runtime --timestamp --sign "$APPLE_SIGN_IDENTITY" "$app/Contents/Helpers/fsearch"
codesign --force --options runtime --timestamp --sign "$APPLE_SIGN_IDENTITY" "$app"
codesign --verify --deep --strict "$app"

submission="$PWD/dist/FinderSearch-$version-$platform-notary.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$submission"
xcrun notarytool submit "$submission" --keychain-profile "$APPLE_NOTARY_PROFILE" --wait --output-format json > "dist/notary-$version-app.json"
if [[ "$(plutil -extract status raw "dist/notary-$version-app.json")" != Accepted ]]; then
    cat "dist/notary-$version-app.json" >&2
    exit 1
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

./scripts/package-dmg.sh --skip-build
dmg="$PWD/dist/FinderSearch-$version-$platform.dmg"
codesign --force --timestamp --sign "$APPLE_SIGN_IDENTITY" "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$APPLE_NOTARY_PROFILE" --wait --output-format json > "dist/notary-$version-dmg.json"
if [[ "$(plutil -extract status raw "dist/notary-$version-dmg.json")" != Accepted ]]; then
    cat "dist/notary-$version-dmg.json" >&2
    exit 1
fi
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"

zip="$PWD/dist/FinderSearch-$version-$platform.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
(
    cd dist
    shasum -a 256 "FinderSearch-$version-$platform.dmg" "FinderSearch-$version-$platform.zip" > SHA256SUMS
    shasum -a 256 "FinderSearch-$version-$platform.dmg" > "FinderSearch-$version-$platform.dmg.sha256"
)
printf 'Release artifacts: %s\n%s\n' "$dmg" "$zip"
