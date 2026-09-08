# WiFi Lens

**A native open-source network diagnostics app for macOS with built-in Wi-Fi analysis.**

Diagnose connectivity issues, analyze Wi-Fi channel congestion, and validate roaming behavior — with results processed locally on your Mac.

**Open source for live analysis. Pro adds monitoring, history, and insights for problems that happen over time.**

[![Downloads](https://img.shields.io/github/downloads/SHIINASAMA/wifi-lens/WiFiLens.dmg?label=Downloads&displayAssetName=false&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![Latest release](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)
[![Discord](https://img.shields.io/badge/Discord-Rabbit%20Hole-5865F2)](https://discord.gg/gH6sTCYaJ7)

<p align="center"><img alt="WiFi Lens showing Wi-Fi spectrum analysis on macOS" src="assets/screenshot-hero.webp" width="800"></p>

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>Download Open-Source Edition</strong></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><strong>Get WiFi Lens Pro</strong></a>
  &nbsp;·&nbsp;
  <a href="https://wifi-lens.shiinalabs.com">Official Website</a>
</p>

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><img src="assets/appstore-badge-en.svg" alt="Download on the Mac App Store" width="190"></a>
</p>

<p align="center">macOS 14+ &nbsp;·&nbsp; Intel &amp; Apple Silicon &nbsp;·&nbsp; No telemetry</p>

<p align="center">
  🔒 <strong>Local-first privacy</strong> — No accounts, no cloud, no telemetry<br>
  🩺 <strong>Evidence-based diagnostics</strong> — Explainable path, DNS, HTTPS, and proxy checks<br>
  🤖 <strong>MCP for AI workflows</strong> — Connect Codex Desktop, Claude Desktop, and other compatible clients to live Wi-Fi data
</p>

---

<p align="center">
  🇺🇸 English · <a href="README.de.md">🇩🇪 Deutsch</a> · <a href="README.es-ES.md">🇪🇸 Español</a> · <a href="README.fr.md">🇫🇷 Français</a> · <a href="README.zh-Hans.md">🇨🇳 简体中文</a> · <a href="README.ja.md">🇯🇵 日本語</a>
</p>
<p align="center">
  <a href="#features">Features</a> · <a href="#when-you-need-pro">When you need Pro</a> · <a href="#editions">Editions</a> · <a href="#ai--mcp-integration">AI / MCP</a> · <a href="#privacy">Privacy</a> · <a href="#get-wifi-lens">Get WiFi Lens</a> · <a href="#development">Development</a> · <a href="#contributing">Contributing</a> · <a href="#license">License</a>
</p>

---

## Features

### Core · OSS & Pro

| Feature | Description | Status |
|---------|-------------|--------|
| 📡 Wi-Fi Scanning | Real-time scan across 2.4 / 5 / 6 GHz bands | Stable |
| 📊 Spectrum View | Gaussian channel occupancy charts | Stable |
| 🎯 Channel Quality | Congestion scores with regional recommendations | Stable |
| 🔍 Network Details | PHY generation, channel width, 802.11k/r/v, WPA3 | Stable |
| 📶 Connection Info | IP, gateway, DNS, MAC, Tx rate, security summary | Stable |
| 🚶 Roaming Test | AP handoff monitoring with session save/load | Stable |
| 🗺️ Channel Heatmap | Per-band occupancy heatmap | Stable |
| 🎧 BLE Scanner | Bluetooth LE discovery, RSSI analysis, tracking | Stable |
| 🎨 Smart Coloring | Deterministic SSID-based color assignment | Stable |
| 🌐 MCP Server | Embedded HTTP API for AI tool integration | Stable |
| 📤 Export | Save charts as PNG or CSV | Stable |
| 🔒 Privacy First | No telemetry; scan data stays on your Mac | Stable |
| ⬆️ Auto-Updates | Sparkle (GitHub) or Mac App Store | Stable |
| 🌍 Localized | English, German, Spanish, Japanese, Chinese | Stable |
| 🩺 Network Self-Check | One-click path, DNS, HTTPS, proxy diagnostics | Preview |
| 📻 AP Radar | Track a selected AP with audio pulse feedback | Preview |

### Available in Pro

| Capability | What it helps you do |
|------------|----------------------|
| 📈 Event Timeline *(Preview)* | Reconstruct when connections roamed, dropped, or changed signal |
| 📋 Statistics *(Preview)* | Compare Wi-Fi behavior across periods instead of relying on memory |
| 💡 Insights *(Preview)* | Turn recorded evidence into explainable findings |
| 🎬 Spectrum Recording | Replay spectrum changes after an intermittent problem |
| 📱 Menu Bar | Keep monitoring reachable without opening the main window |

## When you need Pro

Use Open Source to inspect and diagnose your Wi-Fi right now.

Choose Pro when the problem happens over time:

- Connection drops or slowdowns are intermittent
- You need to reconstruct when roaming or signal changes happened
- You want to compare network behavior across periods
- You want to record spectrum conditions and replay them later
- You want findings that explain recorded evidence

**Open Source helps you inspect. Pro helps you monitor and investigate.**

---

## Editions

Choose based on how you use WiFi Lens:

- **Open Source** — free, inspect and diagnose your Wi-Fi now, available from [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
- **WiFi Lens Pro** — one-time purchase, monitor and investigate over time, available from [Mac App Store](https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8)

| Capability | Open Source | WiFi Lens Pro |
|------------|-------------|---------------|
| Live Wi-Fi analysis | ✅ | ✅ |
| Network diagnostics | ✅ | ✅ |
| Channel recommendations | ✅ | ✅ |
| Event history | — | ✅ |
| Historical statistics | — | ✅ |
| Wi-Fi insights | — | ✅ |
| Spectrum recording | — | ✅ |
| Menu bar monitoring | — | ✅ |

> Both editions are local-first. Pro extends the workflow from live inspection to monitoring and investigation over time.

---

## AI / MCP Integration

WiFi Lens includes an embedded MCP server that lets AI assistants read your local Wi-Fi data. Enable it in Settings, then choose **Copy AI setup prompt** and paste the prompt into an MCP-compatible desktop client such as Codex Desktop or Claude Desktop.

```json
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840"
    }
  }
}
```

For manual setup, use the format your client expects:

```toml
# Codex: ~/.codex/config.toml
[mcp_servers.wifi-lens]
url = "http://127.0.0.1:19840/"
```

```json
// Claude Desktop and other JSON-based clients
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840/"
    }
  }
}
```

Once connected, ask your assistant things like *"What channels are congested near me?"* or *"Which nearby networks support WPA3?"*. The server binds to `127.0.0.1` only — nothing leaves your machine unless you deliberately route it elsewhere.

See the [AI Workflows guide](https://wifi-lens.shiinalabs.com/ai-mcp/) for more examples.

---

<table>
<tr>
<td width="50%" align="center"><img alt="Network Self-Check diagnostics view" src="assets/screenshot-selfcheck.webp" width="100%"><sub>Network Self-Check</sub></td>
<td width="50%" align="center"><img alt="Event Timeline showing connection history" src="assets/screenshot-timeline.webp" width="100%"><sub>Event Timeline (Pro)</sub></td>
</tr>
</table>

### Investigate problems after they happen

Some Wi-Fi problems disappear before you can inspect them. WiFi Lens Pro records connection events and network conditions over time, so you can review what happened after a drop, roam, or signal change.

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><strong>Get WiFi Lens Pro →</strong></a>
</p>

---

## Privacy

WiFi Lens does not collect usage analytics, crash telemetry, or Wi-Fi scan data.

- **Location Services:** macOS requires this permission to expose Wi-Fi SSID names. WiFi Lens does not read GPS position.
- **Region detection:** Uses system locale, hardware-reported channel list, and nearby AP country codes on-device.
- **Network Self-Check:** Resolves public endpoints (`www.apple.com`, `www.msftconnecttest.com`) and may test reachability of configured proxy endpoints.
- **MCP server:** Binds to `127.0.0.1` only. Local tools access data only after you enable it.
- **Update checks:** The GitHub edition contacts GitHub when you request an update check or enable automatic checks.

📋 [Security Policy](SECURITY.md) · 📝 [Changelog](https://github.com/SHIINASAMA/wifi-lens/releases) · ❓ [FAQ](https://wifi-lens.shiinalabs.com/faq/) · 🌐 [Full privacy policy](https://wifi-lens.shiinalabs.com/privacy/)

---

## Get WiFi Lens

Requires **macOS 14 (Sonoma) or later**. Works on both Intel and Apple Silicon. 6 GHz scanning requires Wi-Fi 6E/7 hardware.

- **Open-source edition** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) (free, Sparkle auto-updates)
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8) for monitoring, recording, and investigating problems over time

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><img src="assets/appstore-badge-en.svg" alt="Download on the Mac App Store" width="190"></a>
</p>

> [!IMPORTANT]
> On macOS 14+, **Location Services** must be enabled for the app to read Wi-Fi SSID names. Go to **System Settings → Privacy & Security → Location Services** and enable WiFi Lens when prompted.

---

## Development

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens
git submodule update --init ChartLens
cd WiFiLens

# Build
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" \
  -configuration Debug -destination 'platform=macOS' build

# Run unit tests
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" \
  -configuration Debug -destination 'platform=macOS' \
  -skipPackageUpdates test -only-testing:WiFiLensTests
```

Architecture docs live in [docs/](docs/).

---

## Contributing

### Community

Have a question, found a bug, or want to share an idea?

Join **[Rabbit Hole](https://discord.gg/gH6sTCYaJ7)**, a small community for WiFiLens and other projects.

Bug reports and feature ideas are welcome. See [Contributing Guidelines](.github/CONTRIBUTING.md) for setup, PR conventions, and localization requirements. Substantial contributors may receive a Pro promo code — see [Contributor Recognition](.github/CONTRIBUTING.md#contributor-recognition).

**Contact:** [@WiFiLens on X](https://x.com/WiFiLens) · [wifi-lens@shiinalabs.com](mailto:wifi-lens@shiinalabs.com)

---

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer). MAC vendor data from the [IEEE Registration Authority](https://standards.ieee.org/products-programs/regauth/) — see [Third-Party Notices](docs/THIRD-PARTY-NOTICES.md).

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA — see [LICENSE](LICENSE).
