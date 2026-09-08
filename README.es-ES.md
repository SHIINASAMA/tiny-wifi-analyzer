# WiFi Lens

**Una aplicación nativa de código abierto de diagnóstico de red para macOS con análisis Wi-Fi integrado.**

Diagnostica problemas de conectividad, analiza la congestión del canal Wi-Fi y valida el comportamiento de roaming — con resultados procesados localmente en tu Mac.

**Código abierto para análisis en vivo. Pro añade monitoreo, historial y perspectivas para problemas que ocurren con el tiempo.**

[![Downloads](https://img.shields.io/github/downloads/SHIINASAMA/wifi-lens/WiFiLens.dmg?label=downloads&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![Latest release](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)
[![Discord](https://img.shields.io/badge/Discord-Rabbit%20Hole-5865F2)](https://discord.gg/gH6sTCYaJ7)

<p align="center"><img alt="WiFi Lens análisis de espectro en macOS" src="assets/screenshot-hero.webp" width="800"></p>

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>Descargar edición open source</strong></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><strong>Obtener WiFi Lens Pro</strong></a>
  &nbsp;·&nbsp;
  <a href="https://wifi-lens.shiinalabs.com">Sitio web oficial</a>
</p>

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><img src="assets/appstore-badge-en.svg" alt="Download on the Mac App Store" width="190"></a>
</p>

<p align="center">macOS 14+ &nbsp;·&nbsp; Intel &amp; Apple Silicon &nbsp;·&nbsp; Sin telemetría</p>

<p align="center">
  🔒 <strong>Privacidad local</strong> — Sin cuentas, sin nube, sin telemetría<br>
  🩺 <strong>Diagnóstico basado en evidencia</strong> — Comprobaciones de ruta, DNS, HTTPS y proxy<br>
  🤖 <strong>MCP para flujos de IA</strong> — Conecta Codex Desktop, Claude Desktop y otros clientes compatibles a datos Wi-Fi en vivo
</p>

---

<p align="center">
  <a href="README.md">🇺🇸 English</a> · <a href="README.de.md">🇩🇪 Deutsch</a> · 🇪🇸 Español · <a href="README.fr.md">🇫🇷 Français</a> · <a href="README.zh-Hans.md">🇨🇳 简体中文</a> · <a href="README.ja.md">🇯🇵 日本語</a>
</p>
<p align="center">
  <a href="#funciones">Funciones</a> · <a href="#cuándo-necesitas-pro">Cuándo necesitas Pro</a> · <a href="#ediciones">Ediciones</a> · <a href="#ia--mcp-integración">IA / MCP</a> · <a href="#privacidad">Privacidad</a> · <a href="#obtener-wifi-lens">Obtener WiFi Lens</a> · <a href="#desarrollo">Desarrollo</a> · <a href="#contribuir">Contribuir</a> · <a href="#licencia">Licencia</a>
</p>

---

## Funciones

### Núcleo · OSS & Pro

| Función | Descripción | Estado |
|---------|-------------|--------|
| 📡 Escaneo Wi-Fi | Escaneo en tiempo real de bandas 2,4 / 5 / 6 GHz | Estable |
| 📊 Vista de Espectro | Gráficos gaussianos de ocupación de canales | Estable |
| 🎯 Calidad del Canal | Puntuaciones de congestión con recomendaciones regionales | Estable |
| 🔍 Detalles de Red | Generación PHY, ancho de canal, 802.11k/r/v, WPA3 | Estable |
| 📶 Información de Conexión | IP, gateway, DNS, MAC, tasa Tx, seguridad | Estable |
| 🚶 Prueba de Roaming | Monitoreo de transición AP con gestión de sesiones | Estable |
| 🗺️ Mapa de Calor del Canal | Mapa de calor de ocupación por banda | Estable |
| 🎧 Escáner BLE | Descubrimiento Bluetooth LE, análisis RSSI, seguimiento | Estable |
| 🎨 Colores Inteligentes | Asignación determinista basada en SSID | Estable |
| 🌐 Servidor MCP | API HTTP embebida para herramientas de IA | Estable |
| 📤 Exportar | Guarda gráficos como PNG o CSV | Estable |
| 🔒 Privacidad Primero | Sin telemetría; datos permanecen locales | Estable |
| ⬆️ Actualizaciones Automáticas | Sparkle (GitHub) o Mac App Store | Estable |
| 🌍 Localizado | Inglés, alemán, español, japonés, chino | Estable |
| 🩺 Autodiagnóstico de red | Diagnóstico de ruta, DNS, HTTPS y proxy en un clic | Vista previa |
| 📻 Radar AP | Rastrea un AP con retroalimentación de pulso de audio | Vista previa |

### Disponible en Pro

| Capacidad | Qué te ayuda a hacer |
|-----------|----------------------|
| 📈 Línea temporal de eventos *(Vista previa)* | Reconstruir cuándo hubo roaming, cortes o cambios de señal |
| 📋 Estadísticas *(Vista previa)* | Comparar el comportamiento Wi-Fi entre períodos |
| 💡 Perspectivas *(Vista previa)* | Convertir evidencia registrada en hallazgos explicables |
| 🎬 Grabación de espectro | Reproducir cambios del espectro tras un problema intermitente |
| 📱 Barra de menús | Mantener el monitoreo accesible sin abrir la ventana principal |

## Cuándo necesitas Pro

Usa Open Source para inspeccionar y diagnosticar tu red Wi-Fi ahora mismo.

Elige Pro cuando el problema ocurre con el tiempo:

- Los cortes o la lentitud son intermitentes
- Necesitas reconstruir cuándo ocurrió un roaming o cambio de señal
- Quieres comparar el comportamiento de la red entre períodos
- Quieres grabar condiciones del espectro y reproducirlas después
- Quieres hallazgos que expliquen la evidencia registrada

**Open Source te ayuda a inspeccionar. Pro te ayuda a monitorear e investigar.**

---

## Ediciones

Elige según cómo uses WiFi Lens:

- **Open Source** — gratis, inspecciona y diagnostica tu Wi-Fi ahora, disponible en [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
- **WiFi Lens Pro** — pago único, monitorea e investiga con el tiempo, disponible en [Mac App Store](https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8)

| Capacidad | Open Source | WiFi Lens Pro |
|-----------|-------------|---------------|
| Análisis Wi-Fi en vivo | ✅ | ✅ |
| Diagnóstico de red | ✅ | ✅ |
| Recomendaciones de canal | ✅ | ✅ |
| Historial de eventos | — | ✅ |
| Estadísticas históricas | — | ✅ |
| Perspectivas Wi-Fi | — | ✅ |
| Grabación de espectro | — | ✅ |
| Monitoreo en barra de menús | — | ✅ |

> Ambas ediciones procesan datos localmente. Pro amplía el flujo desde la inspección en vivo hacia el monitoreo y la investigación en el tiempo.

---

## IA / MCP Integración

WiFi Lens incluye un servidor MCP integrado que permite a asistentes de IA leer tus datos Wi-Fi locales. Actívalo en Ajustes, elige **Copiar prompt de configuración de IA** y pega el prompt en un cliente de escritorio compatible con MCP como Codex Desktop o Claude Desktop.

```json
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840"
    }
  }
}
```

Para la configuración manual, usa el formato que espere tu cliente:

```toml
# Codex: ~/.codex/config.toml
[mcp_servers.wifi-lens]
url = "http://127.0.0.1:19840/"
```

```json
// Claude Desktop y otros clientes basados en JSON
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840/"
    }
  }
}
```

Una vez conectado, pregunta a tu asistente cosas como _"¿Qué canales están congestionados cerca de mí?"_ o _"¿Qué redes cercanas admiten WPA3?"_. El servidor se vincula solo a `127.0.0.1` — nada sale de tu máquina a menos que lo enrutes deliberadamente.

Consulta la [guía de flujos de IA](https://wifi-lens.shiinalabs.com/ai-mcp/) para más ejemplos.

---

<table>
<tr>
<td width="50%" align="center"><img alt="Vista de autodiagnóstico de red" src="assets/screenshot-selfcheck.webp" width="100%"><sub>Autodiagnóstico de red</sub></td>
<td width="50%" align="center"><img alt="Línea temporal mostrando historial de conexión" src="assets/screenshot-timeline.webp" width="100%"><sub>Línea temporal (Pro)</sub></td>
</tr>
</table>

### Investiga los problemas después de que ocurren

Algunos problemas de Wi-Fi desaparecen antes de que puedas inspeccionarlos. WiFi Lens Pro registra eventos de conexión y condiciones de red con el tiempo, para que puedas revisar qué ocurrió tras un corte, roaming o cambio de señal.

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><strong>Obtener WiFi Lens Pro →</strong></a>
</p>

---

## Privacidad

WiFi Lens no recopila analíticas de uso, telemetría de fallos ni datos de escaneo Wi-Fi.

- **Servicios de ubicación:** macOS requiere este permiso para exponer nombres SSID Wi-Fi. WiFi Lens no lee posición GPS.
- **Detección de región:** Usa configuración regional del sistema, lista de canales del hardware y códigos de país de APs cercanos en el dispositivo.
- **Autodiagnóstico de red:** Resuelve endpoints públicos (`www.apple.com`, `www.msftconnecttest.com`) y puede comprobar accesibilidad de proxies configurados.
- **Servidor MCP:** Se vincula solo a `127.0.0.1`. Las herramientas locales acceden a datos solo tras activarlo.
- **Comprobaciones de actualización:** La edición GitHub contacta GitHub al solicitar comprobaciones de actualización.

📋 [Política de seguridad](SECURITY.md) · 📝 [Changelog](https://github.com/SHIINASAMA/wifi-lens/releases) · ❓ [FAQ](https://wifi-lens.shiinalabs.com/faq/) · 🌐 [Política de privacidad completa](https://wifi-lens.shiinalabs.com/privacy/)

---

## Obtener WiFi Lens

Requiere **macOS 14 (Sonoma) o posterior**. Funciona en Mac Intel y Apple Silicon. El escaneo de 6 GHz requiere hardware Wi-Fi 6E/7.

- **Edición open source** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) (gratis, Sparkle auto-updates)
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8) para monitorear, grabar e investigar problemas con el tiempo

<p align="center">
  <a href="https://apps.apple.com/app/apple-store/id6776590746?pt=128979395&ct=github_readme&mt=8"><img src="assets/appstore-badge-en.svg" alt="Download on the Mac App Store" width="190"></a>
</p>

> [!IMPORTANT]
> En macOS 14+, los **Servicios de ubicación** deben estar activados para leer nombres SSID Wi-Fi. Ve a **Ajustes del Sistema → Privacidad y Seguridad → Localización**.

---

## Desarrollo

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

Documentación de arquitectura en [docs/](docs/).

---

## Contribuir


### Comunidad

¿Tienes una pregunta, encontraste un error o quieres compartir una idea?

Únete a **[Rabbit Hole](https://discord.gg/gH6sTCYaJ7)**, una pequeña comunidad para WiFiLens y otros proyectos.


---

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer). Datos de proveedores MAC de la [IEEE Registration Authority](https://standards.ieee.org/products-programs/regauth/) — ver [Avisos de terceros](docs/THIRD-PARTY-NOTICES.md).

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA — ver [LICENSE](LICENSE).
