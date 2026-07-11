#!/bin/zsh
set -euo pipefail

plugin_root=${0:A:h:h}
app_root="$HOME/Applications/Codex Usage Float.app"
binary="$app_root/Contents/MacOS/CodexUsageFloat"
module_cache="${TMPDIR:-/tmp}/codex-usage-float-module-cache"

mkdir -p "$app_root/Contents/MacOS" "$app_root/Contents/Resources"
mkdir -p "$module_cache"
cp "$plugin_root/app/Info.plist" "$app_root/Contents/Info.plist"
CLANG_MODULE_CACHE_PATH="$module_cache" clang -fobjc-arc -framework Cocoa -framework QuartzCore -o "$binary" "$plugin_root/app/main.m" "$plugin_root/app/UsageSurfaceView.m"
pkill -x CodexUsageFloat 2>/dev/null || true
open -n "$app_root"
