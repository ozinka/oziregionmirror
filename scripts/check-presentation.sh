#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
swift build --disable-sandbox
bin_path="$(swift build --show-bin-path --disable-sandbox)"
mkdir -p build
swiftc -parse-as-library -module-cache-path "$PWD/.build/swift-cache" -I "$bin_path/Modules" \
    Sources/OziRegionMirror/PresentationSession.swift \
    Sources/OziRegionMirror/PresentationToolbar.swift \
    Tests/Native/ToolbarChecks.swift \
    Sources/OziRegionMirror/CanvasRenderer.swift \
    Sources/OziRegionMirror/CanvasView.swift \
    Sources/OziRegionMirror/MirrorView.swift \
    Sources/OziRegionMirror/MirrorWindow.swift \
    Tests/Native/PresentationChecks.swift "$bin_path/RegionCore.build/"*.o \
    -o build/presentation-check
exec build/presentation-check
