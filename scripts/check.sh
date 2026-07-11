#!/bin/zsh
set -euo pipefail

repository_root=${0:A:h:h}
plugin_root="$repository_root/plugins/codex-usage-float"
module_cache="${TMPDIR:-/tmp}/codex-usage-float-module-cache"
output_binary="${TMPDIR:-/tmp}/CodexUsageFloat-check"

mkdir -p "$module_cache"
plutil -lint "$plugin_root/app/Info.plist"
CLANG_MODULE_CACHE_PATH="$module_cache" clang -fobjc-arc -framework Cocoa -framework QuartzCore -o "$output_binary" "$plugin_root/app/main.m" "$plugin_root/app/UsageSurfaceView.m"
python3 -m json.tool "$repository_root/.agents/plugins/marketplace.json" >/dev/null
python3 -m json.tool "$plugin_root/.codex-plugin/plugin.json" >/dev/null
echo "Checks passed."
