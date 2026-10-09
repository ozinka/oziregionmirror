#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
signing_identity="${OZI_SIGNING_IDENTITY:--}"
swift build -c release --disable-sandbox
bin_path="$(swift build -c release --show-bin-path --disable-sandbox)"
app_path="$PWD/build/OziRegionMirror.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/OziRegionMirror" "$app_path/Contents/MacOS/OziRegionMirror.new"
mv -f "$app_path/Contents/MacOS/OziRegionMirror.new" "$app_path/Contents/MacOS/OziRegionMirror"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
cp Resources/AppIcon.icns "$app_path/Contents/Resources/AppIcon.icns"
codesign --force --sign "$signing_identity" --identifier local.ozi.regionmirror "$app_path"
codesign --verify --strict "$app_path"
if [ "$signing_identity" = "-" ]; then
    echo "Ad-hoc build: Screen Recording permission may need to be renewed after code changes."
    echo "For stable identity, set OZI_SIGNING_IDENTITY to an installed Apple Development or Developer ID signing identity."
fi
echo "Built $app_path"
