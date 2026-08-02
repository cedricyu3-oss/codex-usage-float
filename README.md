# Codex Usage Float

A small, local macOS menu-bar utility for viewing Codex account usage without repeatedly opening settings.

It keeps the current allowance in the macOS menu bar, alongside the other status items. Click the menu-bar item for 5-hour and weekly usage details.

## Features

- Native macOS menu-bar status item.
- 5-hour and weekly quota details, including local reset times.
- No floating window or persistent desktop overlay.
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

If the menu-bar item shows `--`, complete a Codex turn and wait for the next refresh.

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
