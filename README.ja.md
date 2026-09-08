# WiFi Lens

**macOS 向けネイティブオープンソースネットワーク診断アプリ、Wi-Fi 分析を内蔵。**

接続問題の診断、Wi-Fi チャンネル混雑の分析、ローミング動作の検証——すべてローカルで処理されます。

**オープンソースはライブ分析向け。Pro は、時間とともに起こる問題のためのモニタリング・履歴・インサイトを追加します。**

[![Downloads](https://img.shields.io/github/downloads/SHIINASAMA/wifi-lens/WiFiLens.dmg?label=Downloads&displayAssetName=false&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![Latest release](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)
[![Discord](https://img.shields.io/badge/Discord-Rabbit%20Hole-5865F2)](https://discord.gg/gH6sTCYaJ7)

<p align="center"><img alt="WiFi Lens スペクトル分析" src="assets/screenshot-hero.webp" width="800"></p>

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>オープンソース版をダウンロード</strong></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><strong>WiFi Lens Pro を入手</strong></a>
  &nbsp;·&nbsp;
  <a href="https://wifi-lens.shiinalabs.com">公式サイト</a>
</p>

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><img src="assets/appstore-badge-en.svg" alt="Download on the Mac App Store" width="190"></a>
</p>

<p align="center">macOS 14+ &nbsp;·&nbsp; Intel &amp; Apple Silicon &nbsp;·&nbsp; テレメトリなし</p>

<p align="center">
  🔒 <strong>ローカルファーストのプライバシー</strong> — アカウント不要、クラウド送信なし<br>
  🩺 <strong>エビデンスに基づく診断</strong> — パス・DNS・HTTPS・プロキシの到達性チェック<br>
  🤖 <strong>AI ワークフロー向け MCP</strong> — Codex Desktop、Claude Desktop、その他の互換クライアントをライブ Wi-Fi データに接続
</p>

---

<p align="center">
  <a href="README.md">🇺🇸 English</a> · <a href="README.de.md">🇩🇪 Deutsch</a> · <a href="README.es-ES.md">🇪🇸 Español</a> · <a href="README.fr.md">🇫🇷 Français</a> · <a href="README.zh-Hans.md">🇨🇳 简体中文</a> · 🇯🇵 日本語
</p>
<p align="center">
  <a href="#機能">機能</a> · <a href="#pro-が向いているケース">Pro が向いているケース</a> · <a href="#エディション">エディション</a> · <a href="#ai--mcp-統合">AI / MCP</a> · <a href="#プライバシー">プライバシー</a> · <a href="#wifi-lens-を入手">WiFi Lens を入手</a> · <a href="#開発">開発</a> · <a href="#コントリビュート">コントリビュート</a> · <a href="#ライセンス">ライセンス</a>
</p>

---

## 機能

### コア · OSS & Pro

| 機能 | 説明 | ステータス |
|------|------|----------|
| 📡 Wi-Fi スキャン | 2.4 / 5 / 6 GHz 帯域のリアルタイムスキャン | 安定 |
| 📊 スペクトルビュー | チャンネル占有率のガウス曲線チャート | 安定 |
| 🎯 チャンネル品質 | 混雑スコアと地域ベースの推奨 | 安定 |
| 🔍 ネットワーク詳細 | PHY 世代、チャンネル幅、802.11k/r/v、WPA3 | 安定 |
| 📶 接続情報 | IP、ゲートウェイ、DNS、MAC、Tx レート、セキュリティ | 安定 |
| 🚶 ローミングテスト | AP 遷移モニタリングとセッション管理 | 安定 |
| 🗺️ チャンネルヒートマップ | バンドごとの占有ヒートマップ | 安定 |
| 🎧 BLE スキャナ | Bluetooth LE デバイス発見、RSSI 分析、追跡 | 安定 |
| 🎨 スマートカラーリング | SSID ベースの一貫した色割り当て | 安定 |
| 🌐 MCP サーバー | AI ツール連携用の内蔵 HTTP API | 安定 |
| 📤 エクスポート | チャートを PNG または CSV で保存 | 安定 |
| 🔒 プライバシーファースト | テレメトリなし、スキャンデータはローカル保持 | 安定 |
| ⬆️ 自動アップデート | Sparkle（GitHub）または Mac App Store | 安定 |
| 🌍 ローカライズ | 英語・ドイツ語・スペイン語・日本語・中国語 | 安定 |
| 🩺 ネットワーク自己診断 | パス・DNS・HTTPS・プロキシのワンクリック診断 | プレビュー |
| 📻 APレーダー | 選択した AP を音声パルスで追跡 | プレビュー |

### Pro で利用できる機能

| 機能 | 活かせる場面 |
|------|------------|
| 📈 イベントタイムライン *(プレビュー)* | ローミング・切断・信号変化がいつ起きたかを追跡する |
| 📋 統計 *(プレビュー)* | 期間ごとの Wi-Fi の挙動を比較する |
| 💡 インサイト *(プレビュー)* | 記録されたエビデンスを説明可能な発見に変える |
| 🎬 スペクトル録画 | 断続的な問題の後にスペクトル変化を再生する |
| 📱 メニューバー | メインウィンドウを開かずにモニタリングにアクセスする |

## Pro が向いているケース

Open Source は、今この瞬間の Wi-Fi を調査・診断するときに使います。

時間とともに問題が現れる場合は Pro が向いています:

- 切断や低速化が断続的に起こる
- ローミングや信号変化がいつ起きたかを後から把握したい
- 期間ごとのネットワーク挙動を比較したい
- スペクトルの状態を記録し、後から再生したい
- 記録されたエビデンスに基づく説明が欲しい

**Open Source は調査用。Pro は継続観察と原因追究用。**

---

## エディション

使い方に合わせて選べます:

- **オープンソース** — 無料。今の Wi-Fi を調査・診断。[GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) から入手
- **WiFi Lens Pro** — 買い切り。時間軸でのモニタリングと原因追究。[Mac App Store](https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8) から入手

| 機能 | オープンソース | WiFi Lens Pro |
|------|--------------|---------------|
| リアルタイム Wi-Fi 分析 | ✅ | ✅ |
| ネットワーク診断 | ✅ | ✅ |
| チャンネル推奨 | ✅ | ✅ |
| イベント履歴 | — | ✅ |
| 履歴統計 | — | ✅ |
| Wi-Fi インサイト | — | ✅ |
| スペクトル録画 | — | ✅ |
| メニューバー監視 | — | ✅ |

> どちらのエディションもローカル処理です。Pro はライブ分析から、時間軸でのモニタリングと調査へワークフローを広げます。

---

## AI / MCP 統合

WiFi Lens には内蔵 MCP サーバーがあり、AI アシスタントがローカルの Wi-Fi データを読み取れます。設定で有効にし、「AI セットアッププロンプトをコピー」を選んで、Codex Desktop や Claude Desktop などの MCP 互換デスクトップクライアントにプロンプトを貼り付けてください。

```json
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840"
    }
  }
}
```

手動で設定する場合は、クライアントが対応する形式を使ってください：

```toml
# Codex: ~/.codex/config.toml
[mcp_servers.wifi-lens]
url = "http://127.0.0.1:19840/"
```

```json
// Claude Desktop などの JSON ベースのクライアント
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840/"
    }
  }
}
```

接続後、AI アシスタントに _「近くで混雑しているチャンネルは？」_ や _「近くにある WPA3 対応ネットワークは？」_ と尋ねられます。サーバーは `127.0.0.1` のみにバインドされ、意図的にルーティングしない限りデータは外部に出ません。

詳しくは [AI ワークフローガイド](https://wifi-lens.shiinalabs.com/ai-mcp/) をご覧ください。

---

<table>
<tr>
<td width="50%" align="center"><img alt="ネットワーク自己診断画面" src="assets/screenshot-selfcheck.webp" width="100%"><sub>ネットワーク自己診断</sub></td>
<td width="50%" align="center"><img alt="イベントタイムライン" src="assets/screenshot-timeline.webp" width="100%"><sub>イベントタイムライン（Pro）</sub></td>
</tr>
</table>

### 問題のあとで原因を調べる

Wi-Fi の問題には、調査できるようになる前に消えてしまうものがあります。WiFi Lens Pro は接続イベントとネットワーク状態を時間軸で記録するため、切断・ローミング・信号変化のあとに何が起きたかを確認できます。

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><strong>WiFi Lens Pro を入手 →</strong></a>
</p>

---

## プライバシー

WiFi Lens は利用状況の分析、クラッシュテレメトリ、Wi-Fi スキャンデータを収集しません。

- **位置情報サービス：** Wi-Fi SSID 名の読み取りに macOS が必要とする権限です。GPS 位置情報は読み取りません。
- **地域検出：** システムの言語設定、ハードウェアのチャンネルリスト、近隣 AP の国コードをデバイス上で使用します。
- **ネットワーク自己診断：** 公開エンドポイント（`www.apple.com`、`www.msftconnecttest.com`）を解決し、設定されたプロキシの到達性を確認する場合があります。
- **MCP サーバー：** `127.0.0.1` のみにバインド。有効化後にのみローカルツールがデータにアクセスできます。
- **アップデート確認：** GitHub 版はアップデート確認時に GitHub にアクセスします。

📋 [セキュリティポリシー](SECURITY.md) · 📝 [変更履歴](https://github.com/SHIINASAMA/wifi-lens/releases) · ❓ [FAQ](https://wifi-lens.shiinalabs.com/faq/) · 🌐 [プライバシーポリシー全文](https://wifi-lens.shiinalabs.com/privacy/)

---

## WiFi Lens を入手

**macOS 14 (Sonoma) 以降**が必要です。Intel Mac と Apple Silicon の両方で動作します。6 GHz スキャンには Wi-Fi 6E/7 ハードウェアが必要です。

- **オープンソース版** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest)（無料、Sparkle 自動更新）
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8)。時間軸でのモニタリング、記録、原因調査に

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><img src="assets/appstore-badge-en.svg" alt="Download on the Mac App Store" width="190"></a>
</p>

> [!IMPORTANT]
> macOS 14 以降では Wi-Fi SSID 名の読み取りに**位置情報サービス**の有効化が必要です。**システム設定 → プライバシーとセキュリティ → 位置情報サービス**で WiFi Lens を許可してください。

---

## 開発

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

アーキテクチャドキュメントは [docs/](docs/) にあります。

---

## コントリビュート


### コミュニティ

質問、バグの発見、またはアイデアの共有はありますか？

WiFiLens やその他のプロジェクトに関する小さなコミュニティ **[Rabbit Hole](https://discord.gg/gH6sTCYaJ7)** に参加しましょう。


---

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer). MAC ベンダーデータは [IEEE Registration Authority](https://standards.ieee.org/products-programs/regauth/) より——[サードパーティ通知](docs/THIRD-PARTY-NOTICES.md)をご参照ください。

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA — [LICENSE](LICENSE) をご参照ください。
