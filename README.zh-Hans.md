# WiFi Lens

**原生开源 macOS 网络诊断工具，内置 Wi-Fi 分析。**

诊断连接问题、分析 Wi-Fi 信道拥堵、验证漫游行为——所有结果都在本地处理。

**开源版用于实时分析。Pro 为随时间发生的问题增加监控、历史和洞察。**

[![Downloads](https://img.shields.io/github/downloads/SHIINASAMA/wifi-lens/WiFiLens.dmg?label=Downloads&displayAssetName=false&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![Latest release](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)
[![Discord](https://img.shields.io/badge/Discord-Rabbit%20Hole-5865F2)](https://discord.gg/gH6sTCYaJ7)

<p align="center"><img alt="WiFi Lens 频谱分析" src="assets/screenshot-hero.webp" width="800"></p>

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>下载开源版</strong></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><strong>获取 WiFi Lens Pro</strong></a>
  &nbsp;·&nbsp;
  <a href="https://wifi-lens.shiinalabs.com">官方网站</a>
</p>

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><img src="assets/appstore-badge-en.svg" alt="Download on the Mac App Store" width="190"></a>
</p>

<p align="center">macOS 14+ &nbsp;·&nbsp; Intel &amp; Apple Silicon &nbsp;·&nbsp; 无遥测</p>

<p align="center">
  🔒 <strong>本地优先隐私</strong> — 无账号、无云端、无遥测<br>
  🩺 <strong>基于证据的诊断</strong> — 路径、DNS、HTTPS 与代理可达性检查<br>
  🤖 <strong>AI 工作流 MCP 集成</strong> — 连接 Codex Desktop、Claude Desktop 及其他兼容客户端读取实时 Wi-Fi 数据
</p>

---

<p align="center">
  <a href="README.md">🇺🇸 English</a> · <a href="README.de.md">🇩🇪 Deutsch</a> · <a href="README.es-ES.md">🇪🇸 Español</a> · <a href="README.fr.md">🇫🇷 Français</a> · 🇨🇳 简体中文 · <a href="README.ja.md">🇯🇵 日本語</a>
</p>
<p align="center">
  <a href="#功能">功能</a> · <a href="#什么时候需要-pro">什么时候需要 Pro</a> · <a href="#版本">版本</a> · <a href="#ai--mcp-集成">AI / MCP</a> · <a href="#隐私">隐私</a> · <a href="#获取-wifi-lens">获取 WiFi Lens</a> · <a href="#开发">开发</a> · <a href="#贡献">贡献</a> · <a href="#许可">许可</a>
</p>

---

## 功能

### 核心 · OSS & Pro

| 功能 | 说明 | 状态 |
|------|------|------|
| 📡 Wi-Fi 扫描 | 跨 2.4 / 5 / 6 GHz 频段的实时扫描 | 稳定 |
| 📊 频谱视图 | 高斯曲线图展示信道占用 | 稳定 |
| 🎯 信道质量 | 拥堵评分与区域推荐 | 稳定 |
| 🔍 网络详情 | PHY 代际、信道宽度、802.11k/r/v、WPA3 | 稳定 |
| 📶 连接信息 | IP、网关、DNS、MAC、发送速率和安全摘要 | 稳定 |
| 🚶 漫游测试 | AP 切换监控与会话管理 | 稳定 |
| 🗺️ 信道热力图 | 各频段占用热力图 | 稳定 |
| 🎧 BLE 扫描器 | Bluetooth LE 设备发现、RSSI 分析和追踪 | 稳定 |
| 🎨 智能着色 | 基于 SSID 的确定性颜色分配 | 稳定 |
| 🌐 MCP 服务器 | 内嵌 HTTP API，支持 AI 工具集成 | 稳定 |
| 📤 导出 | 保存图表为 PNG 或 CSV | 稳定 |
| 🔒 隐私优先 | 无遥测；扫描数据保留在本地 | 稳定 |
| ⬆️ 自动更新 | Sparkle（GitHub）或 Mac App Store | 稳定 |
| 🌍 本地化 | 英语、德语、西班牙语、日语、中文 | 稳定 |
| 🩺 网络自检 | 一键诊断路径、DNS、HTTPS 与代理 | 预览 |
| 📻 AP 雷达 | 追踪选定接入点并随信号强度发出音频脉冲反馈 | 预览 |

### Pro 提供的能力

| 能力 | 帮你做什么 |
|------|------------|
| 📈 事件时间线 *(预览)* | 还原漫游、断连和信号变化发生的时间 |
| 📋 统计 *(预览)* | 按时段对比 Wi-Fi 行为，而不是靠记忆判断 |
| 💡 洞察 *(预览)* | 把记录到的证据转化为可解释的发现 |
| 🎬 频谱录制 | 在间歇性问题发生后回看频谱变化 |
| 📱 菜单栏 | 不打开主窗口也能继续访问监控 |

## 什么时候需要 Pro

开源版适合立即检查和诊断当前 Wi-Fi。

当问题随时间出现时，选择 Pro：

- 断连或变慢只是偶发出现
- 需要还原漫游或信号变化发生的时间
- 需要对比不同时段的网络行为
- 需要记录频谱状态并稍后回放
- 需要基于记录证据给出可解释的发现

**开源版帮你检查，Pro 帮你持续观察和调查。**

---

## 版本

按你的使用方式选择：

- **开源版** — 免费，立即检查和诊断 Wi-Fi；可从 [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) 获取。
- **WiFi Lens Pro** — 一次性购买，用于长期监控和调查；可从 [Mac App Store](https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8) 获取。

| 能力 | 开源版 | WiFi Lens Pro |
|------|--------|---------------|
| 实时 Wi-Fi 分析 | ✅ | ✅ |
| 网络诊断 | ✅ | ✅ |
| 信道推荐 | ✅ | ✅ |
| 事件历史 | — | ✅ |
| 历史统计 | — | ✅ |
| Wi-Fi 洞察 | — | ✅ |
| 频谱录制 | — | ✅ |
| 菜单栏监控 | — | ✅ |

> 两个版本都在本地处理数据。Pro 将工作流从实时检查扩展到长期监控和调查。

---

## AI / MCP 集成

WiFi Lens 内置 MCP 服务器，AI 助手可读取本地 Wi-Fi 数据。在设置中启用后，选择“复制 AI 设置提示词”，并粘贴到 Codex Desktop、Claude Desktop 等 MCP 兼容桌面客户端。

```json
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840"
    }
  }
}
```

手动配置时，请使用客户端要求的格式：

```toml
# Codex：~/.codex/config.toml
[mcp_servers.wifi-lens]
url = "http://127.0.0.1:19840/"
```

```json
// Claude Desktop 及其他基于 JSON 的客户端
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840/"
    }
  }
}
```

连接后可以问 AI 助手：*"附近哪些信道比较拥堵？"* 或 *"附近有哪些网络支持 WPA3？"*。服务器仅绑定 `127.0.0.1`——除非主动路由，数据不会离开你的电脑。

更多示例请参考 [AI 工作流指南](https://wifi-lens.shiinalabs.com/ai-mcp/)。

---

<table>
<tr>
<td width="50%" align="center"><img alt="网络自检诊断界面" src="assets/screenshot-selfcheck.webp" width="100%"><sub>网络自检</sub></td>
<td width="50%" align="center"><img alt="事件时间线显示连接历史" src="assets/screenshot-timeline.webp" width="100%"><sub>事件时间线（Pro）</sub></td>
</tr>
</table>

### 在问题发生后调查原因

有些 Wi-Fi 问题会在你来得及检查前消失。WiFi Lens Pro 会随时间记录连接事件和网络状态，让你在断连、漫游或信号变化后回看当时发生了什么。

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><strong>获取 WiFi Lens Pro →</strong></a>
</p>

---

## 隐私

WiFi Lens 不收集使用分析、崩溃遥测或 Wi-Fi 扫描数据。

- **定位服务：** macOS 需要此权限才能读取 Wi-Fi SSID 名称。WiFi Lens 不读取 GPS 位置。
- **区域检测：** 使用系统语言设置、硬件上报的信道列表和附近 AP 的国家代码，均在设备上完成。
- **网络自检：** 解析公共端点（`www.apple.com`、`www.msftconnecttest.com`），可能测试已配置代理端点的可达性。
- **MCP 服务器：** 仅绑定 `127.0.0.1`。启用后本地工具方可访问数据。
- **更新检查：** GitHub 版在检查更新时联系 GitHub。

📋 [安全策略](SECURITY.md) · 📝 [更新日志](https://github.com/SHIINASAMA/wifi-lens/releases) · ❓ [常见问题](https://wifi-lens.shiinalabs.com/faq/) · 🌐 [完整隐私政策](https://wifi-lens.shiinalabs.com/privacy/)

---

## 获取 WiFi Lens

需要 **macOS 14 (Sonoma) 或更高版本**。支持 Intel 和 Apple Silicon Mac。6 GHz 扫描需要 Wi-Fi 6E/7 硬件。

- **开源版** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest)（免费，Sparkle 自动更新）
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8)，用于长期监控、录制和调查问题

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><img src="assets/appstore-badge-en.svg" alt="Download on the Mac App Store" width="190"></a>
</p>

> [!IMPORTANT]
> macOS 14+ 需要**定位服务**才能读取 Wi-Fi SSID 名称。前往 **系统设置 → 隐私与安全性 → 定位服务** 允许 WiFi Lens。

---

## 开发

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

架构文档见 [docs/](docs/)。

---

## 贡献


### 社区

有问题、发现了 Bug，还是想分享想法？

加入 **[Rabbit Hole](https://discord.gg/gH6sTCYaJ7)**，一个关于 WiFiLens 和其他项目的小社区。


---

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer)。MAC 厂商数据来自 [IEEE Registration Authority](https://standards.ieee.org/products-programs/regauth/)——详见[第三方声明](docs/THIRD-PARTY-NOTICES.md)。

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA — 详见 [LICENSE](LICENSE)。
