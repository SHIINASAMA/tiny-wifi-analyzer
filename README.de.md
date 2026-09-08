# WiFi Lens

**Eine native Open-Source-Netzwerkdiagnose-App für macOS mit integrierter Wi-Fi-Analyse.**

Diagnostiziere Verbindungsprobleme, analysiere die Kanalauslastung und validiere Roaming-Verhalten — alle Ergebnisse werden lokal auf deinem Mac verarbeitet.

**Open Source für die Live-Analyse. Pro ergänzt Monitoring, Verlauf und Insights für Probleme, die sich erst über die Zeit zeigen.**

[![Downloads](https://img.shields.io/github/downloads/SHIINASAMA/wifi-lens/WiFiLens.dmg?label=downloads&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![Latest release](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)
[![Discord](https://img.shields.io/badge/Discord-Rabbit%20Hole-5865F2)](https://discord.gg/gH6sTCYaJ7)

<p align="center"><img alt="WiFi Lens Spektrum-Analyse auf macOS" src="assets/screenshot-hero.webp" width="800"></p>

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>Open-Source-Edition herunterladen</strong></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><strong>WiFi Lens Pro holen</strong></a>
  &nbsp;·&nbsp;
  <a href="https://wifi-lens.shiinalabs.com">Offizielle Website</a>
</p>

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><img src="assets/appstore-badge-en.svg" alt="Download on the Mac App Store" width="190"></a>
</p>

<p align="center">macOS 14+ &nbsp;·&nbsp; Intel &amp; Apple Silicon &nbsp;·&nbsp; Keine Telemetrie</p>

<p align="center">
  🔒 <strong>Local-first privacy</strong> — Keine Konten, keine Cloud, keine Telemetrie<br>
  🩺 <strong>Evidenzbasierte Diagnose</strong> — Pfad-, DNS-, HTTPS- und Proxy-Prüfungen<br>
  🤖 <strong>MCP für KI-Workflows</strong> — Codex Desktop, Claude Desktop und andere kompatible Clients mit Live-Wi-Fi-Daten verbinden
</p>

---

<p align="center">
  <a href="README.md">🇺🇸 English</a> · 🇩🇪 Deutsch · <a href="README.es-ES.md">🇪🇸 Español</a> · <a href="README.fr.md">🇫🇷 Français</a> · <a href="README.zh-Hans.md">🇨🇳 简体中文</a> · <a href="README.ja.md">🇯🇵 日本語</a>
</p>
<p align="center">
  <a href="#funktionen">Funktionen</a> · <a href="#wann-pro-sinnvoll-ist">Wann Pro sinnvoll ist</a> · <a href="#editionen">Editionen</a> · <a href="#ki--mcp-integration">KI / MCP</a> · <a href="#privatsphäre">Privatsphäre</a> · <a href="#wifi-lens-herunterladen">WiFi Lens herunterladen</a> · <a href="#entwicklung">Entwicklung</a> · <a href="#mitwirken">Mitwirken</a> · <a href="#lizenz">Lizenz</a>
</p>

---

## Funktionen

### Kern · OSS & Pro

| Funktion | Beschreibung | Status |
|----------|-------------|--------|
| 📡 Wi-Fi-Scanning | Echtzeit-Scan über 2,4 / 5 / 6 GHz | Stabil |
| 📊 Spektrum-Ansicht | Gauß-Kanalbelegungsdiagramme | Stabil |
| 🎯 Kanalqualität | Auslastungsbewertungen mit regionalen Empfehlungen | Stabil |
| 🔍 Netzwerkdetails | PHY-Generation, Kanalbreite, 802.11k/r/v, WPA3 | Stabil |
| 📶 Verbindungsinformationen | IP, Gateway, DNS, MAC, Tx-Rate, Sicherheit | Stabil |
| 🚶 Roaming-Test | AP-Wechsel-Überwachung mit Sitzungsverwaltung | Stabil |
| 🗺️ Kanal-Heatmap | Belegungsübersicht pro Band | Stabil |
| 🎧 BLE-Scanner | Bluetooth LE-Erkennung, RSSI-Analyse, Tracking | Stabil |
| 🎨 Intelligente Farbgebung | Deterministische SSID-Farbzuordnung | Stabil |
| 🌐 MCP-Server | Eingebettete HTTP-API für KI-Tools | Stabil |
| 📤 Exportieren | Diagramme als PNG oder CSV speichern | Stabil |
| 🔒 Privatsphäre zuerst | Keine Telemetrie; Scandaten bleiben lokal | Stabil |
| ⬆️ Auto-Updates | Sparkle (GitHub) oder Mac App Store | Stabil |
| 🌍 Lokalisiert | Englisch, Deutsch, Spanisch, Japanisch, Chinesisch | Stabil |
| 🩺 Netzwerk-Selbsttest | Ein-Klick-Diagnose: Pfad, DNS, HTTPS, Proxy | Vorschau |
| 📻 AP-Radar | Zugangspunkt mit Audio-Puls-Feedback verfolgen | Vorschau |

### In Pro verfügbar

| Funktion | Was sie dir hilft zu verstehen |
|----------|--------------------------------|
| 📈 Ereignis-Zeitachse *(Vorschau)* | Nachvollziehen, wann Verbindungen roamten, abbrachen oder das Signal wechselte |
| 📋 Statistiken *(Vorschau)* | Wi-Fi-Verhalten über Zeiträume vergleichen |
| 💡 Erkenntnisse *(Vorschau)* | Aufzeichnungen in belegbare Erkenntnisse überführen |
| 🎬 Spektrum-Aufzeichnung | Spektrumsänderungen nach einem zeitweiligen Problem erneut prüfen |
| 📱 Menüleiste | Monitoring erreichbar halten, ohne das Hauptfenster zu öffnen |

## Wann Pro sinnvoll ist

Nutze Open Source, um dein Wi-Fi sofort zu untersuchen und zu diagnostizieren.

Wähle Pro, wenn das Problem sich über die Zeit zeigt:

- Abbrüche oder Langsamkeit treten nur gelegentlich auf
- Du willst nachvollziehen, wann Roaming oder Signalwechsel passiert sind
- Du willst Netzwerkverhalten über Zeiträume vergleichen
- Du willst Spektrumbedingungen aufzeichnen und später wiedergeben
- Du willst Erkenntnisse mit aufgezeichneten Belegen verstehen

**Open Source hilft beim Untersuchen. Pro hilft beim Überwachen und Untersuchen über Zeit.**

---

## Editionen

Wähle anhand deiner Nutzung:

- **Open Source** — kostenlos, Wi-Fi jetzt untersuchen und diagnostizieren, verfügbar über [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
- **WiFi Lens Pro** — Einmalkauf, über die Zeit überwachen und untersuchen, verfügbar im [Mac App Store](https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8)

| Funktion | Open Source | WiFi Lens Pro |
|----------|-------------|---------------|
| Live-Wi-Fi-Analyse | ✅ | ✅ |
| Netzwerkdiagnose | ✅ | ✅ |
| Kanalempfehlungen | ✅ | ✅ |
| Ereignisverlauf | — | ✅ |
| Historische Statistiken | — | ✅ |
| Wi-Fi-Erkenntnisse | — | ✅ |
| Spektrum-Aufzeichnung | — | ✅ |
| Menüleisten-Monitoring | — | ✅ |

> Beide Editionen verarbeiten Daten lokal. Pro erweitert den Workflow von der Live-Analyse zu Monitoring und Untersuchung über Zeit.

---

## KI / MCP Integration

WiFi Lens enthält einen eingebetteten MCP-Server, der KI-Assistenten den Zugriff auf lokale Wi-Fi-Daten ermöglicht. Aktiviere ihn in den Einstellungen, wähle **KI-Setup-Prompt kopieren** und füge den Prompt in einen MCP-kompatiblen Desktop-Client wie Codex Desktop oder Claude Desktop ein.

```json
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840"
    }
  }
}
```

Für die manuelle Einrichtung verwende das Format deines Clients:

```toml
# Codex: ~/.codex/config.toml
[mcp_servers.wifi-lens]
url = "http://127.0.0.1:19840/"
```

```json
// Claude Desktop und andere JSON-basierte Clients
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840/"
    }
  }
}
```

Nach der Verbindung kannst du dein KI-Tool Fragen stellen wie _„Welche Kanäle sind bei mir überlastet?“_ oder _„Welche Netzwerke in der Nähe unterstützen WPA3?“_. Der Server bindet nur an `127.0.0.1` — nichts verlässt deine Maschine, außer du leitest es bewusst woandershin.

Siehe den [KI-Workflows-Leitfaden](https://wifi-lens.shiinalabs.com/ai-mcp/) für weitere Beispiele.

---

<table>
<tr>
<td width="50%" align="center"><img alt="Netzwerk-Selbsttest Diagnoseansicht" src="assets/screenshot-selfcheck.webp" width="100%"><sub>Netzwerk-Selbsttest</sub></td>
<td width="50%" align="center"><img alt="Ereignis-Zeitachse mit Verbindungshistorie" src="assets/screenshot-timeline.webp" width="100%"><sub>Ereignis-Zeitachse (Pro)</sub></td>
</tr>
</table>

### Probleme untersuchen, nachdem sie passiert sind

Manche Wi-Fi-Probleme verschwinden, bevor du sie untersuchen kannst. WiFi Lens Pro zeichnet Verbindungsereignisse und Netzwerkbedingungen über die Zeit auf, damit du nach einem Abbruch, Roaming oder Signalwechsel rekonstruieren kannst, was passiert ist.

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><strong>WiFi Lens Pro holen →</strong></a>
</p>

---

## Privatsphäre

WiFi Lens sammelt keine Nutzungsanalysen, Crash-Telemetrie oder Wi-Fi-Scandaten.

- **Standortdienste:** macOS erfordert diese Berechtigung zum Auslesen von Wi-Fi-SSID-Namen. WiFi Lens liest keine GPS-Position.
- **Regionserkennung:** Nutzt Systemsprache, hardwaregemeldete Kanalliste und Ländercodes benachbarter APs auf dem Gerät.
- **Netzwerk-Selbsttest:** Löst öffentliche Endpunkte auf (`www.apple.com`, `www.msftconnecttest.com`) und prüft ggf. die Erreichbarkeit konfigurierter Proxy-Endpunkte.
- **MCP-Server:** Bindet nur an `127.0.0.1`. Lokale Tools greifen erst nach Aktivierung auf Daten zu.
- **Update-Prüfungen:** Die GitHub-Edition kontaktiert GitHub bei Update-Anfragen.

📋 [Sicherheitsrichtlinie](SECURITY.md) · 📝 [Changelog](https://github.com/SHIINASAMA/wifi-lens/releases) · ❓ [FAQ](https://wifi-lens.shiinalabs.com/faq/) · 🌐 [Vollständige Datenschutzerklärung](https://wifi-lens.shiinalabs.com/privacy/)

---

## WiFi Lens herunterladen

Erfordert **macOS 14 (Sonoma) oder höher**. Funktioniert auf Intel- und Apple Silicon-Macs. 6-GHz-Scanning erfordert Wi-Fi-6E/7-Hardware.

- **Open-Source-Edition** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) (kostenlos, Sparkle Auto-Updates)
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8) für Monitoring, Aufzeichnung und Untersuchung über Zeit

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><img src="assets/appstore-badge-en.svg" alt="Download on the Mac App Store" width="190"></a>
</p>

> [!IMPORTANT]
> Unter macOS 14+ müssen die **Standortdienste** aktiviert sein, damit die App Wi-Fi-SSIDs lesen kann. Gehe zu **Systemeinstellungen → Datenschutz & Sicherheit → Standortdienste**.

---

## Entwicklung

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

Architekturdocs findest du in [docs/](docs/).

---

## Mitwirken


### Community

Haben Sie eine Frage, einen Fehler gefunden oder möchten Sie eine Idee teilen?

Treten Sie **[Rabbit Hole](https://discord.gg/gH6sTCYaJ7)** bei, einer kleinen Community für WiFiLens und andere Projekte.


---

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer). MAC-Vendor-Daten von der [IEEE Registration Authority](https://standards.ieee.org/products-programs/regauth/) — siehe [Third-Party Notices](docs/THIRD-PARTY-NOTICES.md).

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA — siehe [LICENSE](LICENSE).
