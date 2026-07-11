#!/bin/zsh
set -euo pipefail

repository_root=${0:A:h}
exec zsh "$repository_root/plugins/codex-usage-float/scripts/build-and-launch.sh"
