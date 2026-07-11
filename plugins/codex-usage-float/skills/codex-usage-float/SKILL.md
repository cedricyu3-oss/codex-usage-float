---
name: codex-usage-float
description: Help install, launch, and diagnose the local macOS menu-bar monitor for the latest Codex 5-hour and weekly usage snapshots.
---

# Codex Usage Float

Use this skill when the user asks to launch or diagnose the local Codex quota monitor.

The monitor is built from `app/main.m` and reads the latest `rate_limits` snapshot that Codex already wrote to `~/.codex/sessions`. It derives remaining quota as `100 - used_percent` for the 300-minute and 10,080-minute windows. It must never read, display, or transmit credentials.

To install or relaunch it, run:

```zsh
zsh plugins/codex-usage-float/scripts/build-and-launch.sh
```

If no values appear, ask the user to complete a Codex turn, then refresh the app. Do not fabricate values when no local snapshot exists. This utility is macOS-only and requires Apple's Command Line Tools.
