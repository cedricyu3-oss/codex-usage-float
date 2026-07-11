# Privacy

Codex Usage Float runs entirely on the local Mac.

It reads only the newest `rate_limits` object already present in Codex session records under `~/.codex/sessions`. It does not read login credentials, make network requests, send analytics, or upload usage data.

The session-record format is an internal Codex implementation detail. If it changes, the app intentionally shows no value instead of estimating one.
