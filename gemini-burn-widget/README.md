# 🔥 Gemini Burn • Antigravity Desktop Monitor

<p align="center">
  <img src="assets/social_preview.png" alt="Gemini Burn • Antigravity Desktop Monitor" width="100%" style="border-radius: 16px; box-shadow: 0 20px 40px rgba(0,0,0,0.5);" />
</p>

<p align="center">
  <b>English</b> · <a href="README.pt-BR.md">Português (BR)</a> · <a href="README.es.md">Español</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ru.md">Русский</a>
</p>

<p align="center">
  <b>Real-time request, token burn rate, and quota monitor for Gemini and Antigravity on Linux.</b><br>
  Built with the refined aesthetic of <b>Apple Widgets</b> (macOS Sonoma / iOS), glassmorphism effects, and native <b>GNOME Shell</b> integration.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20GNOME%2045%2B-blue?style=flat-square&logo=linux" alt="Platform" />
  <img src="https://img.shields.io/badge/Python-3.10%2B-brightgreen?style=flat-square&logo=python" alt="Python" />
  <img src="https://img.shields.io/badge/Style-Apple%20HIG%20Dark-black?style=flat-square&logo=apple" alt="Apple Design" />
  <img src="https://img.shields.io/badge/License-MIT-orange?style=flat-square" alt="License" />
</p>

---

## ✨ Features & Highlights

- 🍏 **Apple Widget Inspired Design:** 
  - Translucent `#2f2f2f` base container with frosted *glassmorphism* and *backdrop blur*.
  - Obsidian black internal cards (`#151515`) featuring continuous smooth corners (*squircles* with `border-radius: 20px`) and specular micro-lighting inner rings.
  - Clean typography with natural optical character tracking.
- 🚦 **Dynamic System Colors & Smart Status (Apple HIG):**
  - 🟢 **0% to 49% • `Active ⚡` (Apple System Green `#30D158`):** Safe consumption zone, relaxed pace, sleek green accent.
  - 🟡 **50% to 69% • `Moderate ⚡` (Apple System Yellow `#FFD60A`):** Cautionary heads-up after crossing half the daily allowance.
  - 🔴 **70%+ • `Blazing 🔥` (Apple System Red `#FF453A`):** High burn velocity approaching daily limits.
  - 🎯 **Full Visual Harmony:** Status badge, progress bar, hourly velocity (`req/h`), and percentages update in perfect synchrony.
- ⚡ **Zero-Config Local Auto-Tracking:**
  - Directly analyzes local Antigravity session logs (`~/.gemini/antigravity/brain/` and `~/.gemini/antigravity-ide/brain/`).
  - No API keys needed to track your Antigravity workflow.
  - Captures real input/output tokens or performs accurate context-based estimation.
- 📈 **Velocity Metrics & History:**
  - **Calendar Week:** Cumulative weekly tracking starting every Monday at 00:00:00.
  - **Hourly Burn Rate:** Continuous real-time measurement of requests and tokens burned per hour.
  - **7-Day Sparkline:** Mini bar chart showing historical request peaks with a smart highlight on today.
  - **Tool Call Counter:** Tracks total agent function executions and background commands.
- 🎛️ **Multi-Display Modes:**
  1. **Top Bar Panel (GNOME Shell Extension):** Sits discreetly next to your system tray icons and reveals the full widget on click.
  2. **Local Web Dashboard:** Accessible in any modern browser via `http://127.0.0.1:5678/`.
  3. **Floating Desktop Widget:** Standalone native GTK 4 / WebKitGTK draggable window.
  4. **Terminal CLI Dashboard:** Live interactive console interface akin to `htop`/`btop`.

---

## 🚀 Quick Install (Single Command)

Install Gemini Burn directly through your terminal with one command (no `sudo` required):

```bash
curl -sSL https://raw.githubusercontent.com/andreporto/gemini-burn-widget/main/install.sh | bash
```

### What the installer handles automatically:
1. Installs the native GNOME Shell extension into `~/.local/share/gnome-shell/extensions/gemini-burn@andreporto/`.
2. Creates and enables the background service in `systemd --user` (starts automatically on system boot).
3. Adds a desktop launcher to your applications menu.

> [!IMPORTANT]
> ### ⚠️ Notice for Wayland Users (Zorin OS, Ubuntu, Fedora)
> Under **Wayland** (the default on modern GNOME 45+ distributions), the GNOME Shell process acts directly as the display compositor. For system stability reasons, GNOME **disallows runtime shell restarts** (the legacy X11 `Alt + F2` followed by `r` shortcut does not work in Wayland).
>
> **What this means:**
> - When installing the extension for the first time or updating visual code (`extension.js` or `stylesheet.css`), GNOME keeps the previously loaded JavaScript cached in RAM during the active session.
> - **Workaround:** Simply **Log Out** and log back into your user session (or restart your PC). Upon logging back in, GNOME Shell will cleanly load the updated files from disk.

---

## 🛠️ Manual Installation via Git

If you prefer to inspect and run from a local git clone:

```bash
# 1. Clone the repository
git clone https://github.com/andreporto/gemini-burn-widget.git
cd gemini-burn-widget

# 2. Run the local installer
./install.sh
```

---

## 🖥️ Usage Modes

| Mode | Command | Description |
| :--- | :--- | :--- |
| **Top Bar** | Click the `🔥` icon in the panel | Native popup card with real-time stats |
| **Web Dashboard** | `./main.py --web` | Opens local web server at `http://127.0.0.1:5678/` |
| **Floating Widget** | `./main.py --widget` | Draggable desktop glass window |
| **Terminal (CLI)** | `./main.py --cli` | Live interactive terminal dashboard |

---

## ⚙️ Service Management (Systemd)

The collector daemon runs purely in user space without root permissions:

```bash
# Check metrics collector status
systemctl --user status gemini-burn.service

# Restart the service
systemctl --user restart gemini-burn.service

# Stop the service
systemctl --user stop gemini-burn.service
```

---

## 🔒 Privacy & Security

- **100% Local & Offline:** No prompt content, code, tokens, or history ever leaves your machine.
- **Passive Read-Only:** Only performs passive local parsing of metrics produced by your Antigravity workflow.
- **Local Storage:** Configuration and manual API calls are persisted locally in `~/.gemini-burn/`.

---

## 🤝 Contributing

Contributions from the open-source community are warmly welcome! If you want to report a bug, suggest metrics, or submit PRs:

1. **Fork** the repository.
2. Create a feature branch (`git checkout -b feature/my-new-feature`).
3. Commit your changes (`git commit -m 'feat: add custom daily token threshold'`).
4. Push to your branch (`git push origin feature/my-new-feature`).
5. Open a **Pull Request**.

For detailed setup instructions, GNOME extension development tips, and log tracing, check our [Contribution Guide (CONTRIBUTING.md)](CONTRIBUTING.md).

---

## ☕ Support the Project

If **Gemini Burn** helps supercharge your daily workflow and you'd like to support continued development, consider buying me a coffee! ☕

<p align="left">
  <img src="https://img.shields.io/badge/PIX-Support%20via%20PIX-32BCAD?style=for-the-badge&logo=pix&logoColor=white" alt="Support via Pix" />
</p>

> **PIX Key (Random):**  
> `883e07ea-968b-44eb-ba00-4ee5cef1221d`  
> *(Any amount is deeply appreciated and fuels upcoming features! 🔥)*

---

## 📄 License

Distributed under the [MIT](LICENSE) License. Built for the open-source developer community.
