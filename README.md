# Codex Usage Float

A small, local macOS floating utility for viewing Codex account usage without repeatedly opening settings.

It displays the remaining 5-hour allowance as a compact floating ball. Click to expand 5-hour and weekly usage details; click again to collapse. The panel can be dragged, stays on screen when expanded, and returns to its original ball position when collapsed.

## Features

- Native macOS frosted-material visual style and system accent color.
- Compact 5-hour quota ball with a progress ring.
- Expandable 5-hour and weekly quota details, including local reset times.
- Smooth expand/collapse animation and drag support.
- Reads only local Codex session snapshots; no credentials, analytics, or network requests.
- Includes a Codex marketplace-ready plugin layout.

## Requirements

- macOS 13 or later.
- Apple Command Line Tools (`xcode-select --install`) for `clang`.
- Codex logged in locally and at least one completed Codex turn, so a current usage snapshot exists.

## Run locally

```zsh
git clone https://github.com/cedricyu3-oss/codex-usage-float.git
cd codex-usage-float
zsh run.sh
```

This builds `~/Applications/Codex Usage Float.app` and launches it. The utility refreshes every 20 seconds.

If the ball shows `--`, complete a Codex turn and wait for the next refresh.

## Install as a Codex plugin

From the repository root:

```zsh
codex plugin marketplace add .
codex plugin add codex-usage-float@codex-usage-float
```

For a GitHub-hosted marketplace, replace `.` with the repository source, for example:

```zsh
codex plugin marketplace add cedricyu3-oss/codex-usage-float --ref main
codex plugin add codex-usage-float@codex-usage-float
```

Start a new Codex task after installation so the plugin skill is available.

## Development

```zsh
zsh scripts/check.sh
zsh run.sh
```

The macOS app source lives in `plugins/codex-usage-float/app/`. The plugin marketplace manifest is `.agents/plugins/marketplace.json`.

## Privacy

See [PRIVACY.md](PRIVACY.md). The tool is local-only and does not make network requests.

## License

[MIT](LICENSE)
