<p align="center">
  <img width="128" height="128" alt="LaunchNow" src="https://github.com/user-attachments/assets/b4bf72d3-a272-44ad-ab9a-d02248a9fa67" />
</p>

<h1 align="center">LaunchNow</h1>

<p align="center">
  <strong>An alternative Launchpad application for macOS</strong>
</p>

<p align="center">
  <a href="https://github.com/ggkevinnnn/LaunchNow/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ggkevinnnn/LaunchNow" alt="License" /></a>
  <a href="#"><img src="https://img.shields.io/badge/language-Swift-orange.svg" alt="Language" /></a>
  <a href="https://github.com/ggkevinnnn/LaunchNow/releases/latest"><img src="https://img.shields.io/github/v/release/ggkevinnnn/LaunchNow" alt="GitHub Release" /></a>
  <a href="https://github.com/ggkevinnnn/LaunchNow/releases"><img src="https://img.shields.io/github/downloads/ggkevinnnn/LaunchNow/total" alt="Downloads" /></a>
  <a href="https://github.com/ggkevinnnn/LaunchNow/releases/latest"><img src="https://img.shields.io/badge/platform-macOS%2015%2B-blue" alt="Platform" /></a>
</p>

<!-- Language Switcher -->
<p align="center">
  <a href="#readme-en"><kbd> <b>English</b> </kbd></a>
  <b> · </b>
  <a href="#readme-zh"><kbd> <b>中文</b> </kbd></a>
</p>

---

<a name="readme-en"></a>

## 🇬🇧 English

**LaunchNow** is an alternative macOS Launchpad application designed for macOS Sequoia and later. It provides a smoother, more customizable launchpad experience with both **Tahoe-style (macOS 15)** and **Classic-style** interfaces.

### ✨ Features

- **🎨 Dual Style Support** — Switch between the modern macOS 15 Tahoe-style fullscreen Launchpad and a classic compact window mode
- **📁 Folder Management** — Drag an app onto another app to quickly create a folder; drag apps in/out of folders freely
- **🔄 Icon Rearrangement** — Drag and drop app icons to customize your layout with smooth animations
- **🔒 Lock Mode** — Hold the `Option` key to enable lock mode, preventing other icons from moving while you create folders or add apps to folders
- **🔍 App Search** — Real-time search across all apps including those inside folders
- **⌨️ Full Keyboard Navigation** — Use `Tab` / `Shift+Tab` to flip pages, arrow keys to select apps, and `Return` to launch
- **🖱️ Trackpad Gesture** — 4-finger trackpad gesture support for quick access (configurable)
- **🧹 Hidden Apps** — Hide unwanted apps from the grid without deleting them
- **📦 Import / Export** — Backup and restore your layout configuration
- **📐 Adjustable Icon Size** — Customize icon scale to your preference
- **🪟 Glass Effect** — Enable/disable the frosted glass background effect
- **🌍 Multi-language** — Supports 13 languages with real-time language switching
- **🔄 Auto Update** — Built-in update checker with GitHub release integration
- **📋 Scroll Sensitivity** — Adjust trackpad/mouse scroll sensitivity for page turning

### 📸 Screenshots

<table>
  <tr>
    <td><img width="960" alt="Tahoe Style" src="https://github.com/user-attachments/assets/69eaf1bb-746e-4c9c-9d38-791dbee14194" /></td>
    <td><img width="960" alt="Classic Style" src="https://github.com/user-attachments/assets/c6bffd5c-9dcf-4b1c-8b34-a9d7f964a78d" /></td>
  </tr>
  <tr>
    <td align="center">Tahoe Style (Fullscreen)</td>
    <td align="center">Classic Mode (Windowed)</td>
  </tr>
</table>

### 🚀 Getting Started

#### Installation

1. Download the latest release from the [Releases page](https://github.com/ggkevinnnn/LaunchNow/releases/latest)
2. Drag `LaunchNow.app` to your `Applications` folder
3. Launch the app — it runs in the background and opens the launchpad window

#### Quick Usage

| Action | How |
|---|---|
| **Open Launchpad** | Click the Dock icon or set a custom trigger |
| **Launch an app** | Click on the app icon |
| **Rearrange icons** | Drag an app to a new position |
| **Create a folder** | Drag one app onto another app |
| **Add to folder** | Drag an app onto a folder |
| **Remove from folder** | Open the folder and drag the app outside |
| **Lock Mode** | Hold `Option` while dragging (recommended for folder operations) |
| **Search** | Type in the search field at the top |
| **Turn pages** | Scroll with trackpad/mouse or use `Tab` / `Shift+Tab` |
| **Keyboard navigation** | Press `↓` or `Return` to activate, then use arrow keys |
| **Close / Hide** | Press `Esc` |

#### Auto Launch (Optional)

Add LaunchNow to your **Login Items** in System Settings → General → Login Items to have it automatically run in the background at startup.

### ⚙️ Configuration

LaunchNow provides a comprehensive settings panel:

- **Display Mode** — Toggle between fullscreen Tahoe style and classic window mode
- **Icon Size** — Adjust the scale of app icons
- **Show App Name** — Toggle labels below icons
- **Scroll Sensitivity** — Fine-tune scroll speed for page turning
- **Glass Effect** — Toggle the frosted glass background
- **Trackpad Gesture** — Enable/disable 4-finger gesture
- **Hidden Apps** — Select apps to hide from view
- **Scanned Folders** — Customize which folders LaunchNow scans for apps
- **Import / Export** — Backup and restore your layout
- **Language** — Switch the display language in real time
- **Check for Updates** — Automatically check for new versions

### 🌐 Localization

LaunchNow is available in **13 languages**:

| Language | Locale | Translator |
|---|---|---|
| English | `en` | — |
| 简体中文 (Simplified Chinese) | `zh-Hans` | — |
| Nederlands (Dutch) | `nl` | @OABsoftware |
| Русский (Russian) | `ru` | @Leoxoo |
| Български (Bulgarian) | `bg` | Трифон Иванов |
| 日本語 (Japanese) | `ja` | @endianoia |
| 한국어 (Korean) | `ko` | @D-KoLee |
| Italiano (Italian) | `it` | @wd006 |
| Türkçe (Turkish) | `tr` | @wd006 |
| Deutsch (German) | `de` | — |
| Français (French) | `fr` | — |
| Español (Spanish) | `es` | — |
| Português (Portugal) | `pt-PT` | — |
| Português (Brasil) | `pt-BR` | — |

### 🛠️ Technical Details

- **Language:** Swift 5
- **Framework:** SwiftUI, AppKit
- **Minimum Deployment:** macOS 15 Sequoia
- **Architecture:** Pure Swift with Combine and SwiftData for persistence
- **Icon Caching:** Multi-level LRU cache with background preloading for smooth scrolling
- **Drag & Drop:** Custom drag system with folder handoff and edge-triggered page flipping

### 🤝 Contributing

Contributions are welcome! Whether it's bug reports, feature requests, translations, or code improvements, feel free to open an issue or pull request.

#### Translators

Interested in adding a new language? Fork the repo, add your translation to a new `.lproj/Localizable.strings` file, and submit a PR!

### 🙏 Acknowledgments

Special thanks to all contributors and translators who helped make LaunchNow better:

- Code improvement and optimization by @dizzycoder1112
- Dutch translation by @OABsoftware
- Russian translation by @Leoxoo
- Bulgarian translation by Трифон Иванов
- Japanese translation by @endianoia
- Korean translation by @D-KoLee
- Italian & Turkish translations by @wd006

### 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<details>
<summary><b>🇨🇳 简体中文</b></summary>

<br>

<a name="readme-zh"></a>

## 🇨🇳 简体中文

**LaunchNow** 是一款适用于 macOS Sequoia 及以上版本的替代 Launchpad 应用。它提供更流畅、更可定制的启动台体验，支持 **macOS 15 太浩湖风格** 和 **经典风格** 两种界面。

### ✨ 功能特性

- **🎨 双风格支持** — 在 macOS 15 太浩湖风格全屏启动台和经典紧凑窗口模式之间自由切换
- **📁 文件夹管理** — 将应用拖到另一个应用上快速创建文件夹；自由拖入/拖出文件夹
- **🔄 图标重新排列** — 拖拽应用图标自定义布局，带有流畅的动画效果
- **🔒 锁定模式** — 按住 `Option` 键启用锁定模式，创建文件夹或添加应用到文件夹时其他图标不会移动
- **🔍 应用搜索** — 实时搜索所有应用，包括文件夹内的应用
- **⌨️ 完整键盘导航** — 使用 `Tab` / `Shift+Tab` 翻页，方向键选择应用，回车键启动
- **🖱️ 触控板手势** — 支持四指触控板手势快速呼出启动台
- **🧹 隐藏应用** — 从网格中隐藏不需要的应用，无需删除
- **📦 导入 / 导出** — 备份和恢复您的布局配置
- **📐 可调图标大小** — 自定义图标缩放比例
- **🪟 玻璃效果** — 开启或关闭毛玻璃背景效果
- **🌍 多语言支持** — 支持 13 种语言，实时切换
- **🔄 自动更新** — 内置更新检查，集成 GitHub Release
- **📋 滚动灵敏度** — 调节触控板/鼠标翻页灵敏度

### 📸 截图

<table>
  <tr>
    <td><img width="960" alt="太浩湖风格" src="https://github.com/user-attachments/assets/69eaf1bb-746e-4c9c-9d38-791dbee14194" /></td>
    <td><img width="960" alt="经典风格" src="https://github.com/user-attachments/assets/c6bffd5c-9dcf-4b1c-8b34-a9d7f964a78d" /></td>
  </tr>
  <tr>
    <td align="center">太浩湖风格（全屏）</td>
    <td align="center">经典模式（窗口）</td>
  </tr>
</table>

### 🚀 快速开始

#### 安装

1. 从 [Releases 页面](https://github.com/ggkevinnnn/LaunchNow/releases/latest) 下载最新版本
2. 将 `LaunchNow.app` 拖入 `应用程序` 文件夹
3. 启动应用 — 它将后台运行并打开启动台窗口

#### 快速操作指南

| 操作 | 方式 |
|---|---|
| **打开启动台** | 点击 Dock 图标或设置自定义触发方式 |
| **启动应用** | 点击应用图标 |
| **重排图标** | 拖拽应用到新位置 |
| **创建文件夹** | 将一个应用拖到另一个应用上 |
| **添加到文件夹** | 将应用拖到文件夹上 |
| **移出文件夹** | 打开文件夹，将应用拖到外部 |
| **锁定模式** | 拖拽时按住 `Option` 键（推荐在文件夹操作时使用） |
| **搜索** | 在顶部的搜索框中输入文字 |
| **翻页** | 使用触控板/鼠标滚动，或按 `Tab` / `Shift+Tab` |
| **键盘导航** | 按 `↓` 或 `Return` 激活，然后使用方向键 |
| **关闭 / 隐藏** | 按 `Esc` |

#### 开机自启（可选）

在 **系统设置 → 通用 → 登录项** 中添加 LaunchNow，即可在开机时自动后台运行。

### ⚙️ 设置选项

LaunchNow 提供了丰富的设置面板：

- **显示模式** — 在全屏太浩湖风格与经典窗口模式之间切换
- **图标大小** — 调整应用图标的缩放比例
- **显示应用名称** — 切换图标下方标签的显示
- **滚动灵敏度** — 精细调节翻页滚轮速度
- **玻璃效果** — 切换毛玻璃背景
- **触控板手势** — 启用/禁用四指手势
- **隐藏应用** — 选择要隐藏的应用
- **扫描文件夹** — 自定义 LaunchNow 扫描应用的目录
- **导入 / 导出** — 备份和恢复布局
- **语言** — 实时切换显示语言
- **检查更新** — 自动检查新版本

### 🌐 本地化

LaunchNow 支持 **13 种语言**：

| 语言 | 区域代码 | 翻译者 |
|---|---|---|
| English | `en` | — |
| 简体中文 | `zh-Hans` | — |
| Nederlands | `nl` | @OABsoftware |
| Русский | `ru` | @Leoxoo |
| Български | `bg` | Трифон Иванов |
| 日本語 | `ja` | @endianoia |
| 한국어 | `ko` | @D-KoLee |
| Italiano | `it` | @wd006 |
| Türkçe | `tr` | @wd006 |
| Deutsch | `de` | — |
| Français | `fr` | — |
| Español | `es` | — |
| Português (Portugal) | `pt-PT` | — |
| Português (Brasil) | `pt-BR` | — |

### 🛠️ 技术细节

- **语言：** Swift 5
- **框架：** SwiftUI, AppKit
- **最低部署：** macOS 15 Sequoia
- **架构：** 纯 Swift，使用 Combine 和 SwiftData 持久化
- **图标缓存：** 多级 LRU 缓存，支持后台预加载确保流畅滚动
- **拖拽系统：** 自定义拖拽实现，支持文件夹接力拖拽和边缘触发的页面翻转

### 🤝 贡献

欢迎贡献代码！无论是报告 Bug、提出新功能、提交翻译还是代码改进，都可以随时提交 Issue 或 Pull Request。

#### 翻译贡献

想添加新的语言？Fork 本仓库，在 `.lproj/Localizable.strings` 文件中添加翻译，然后提交 PR！

### 🙏 致谢

感谢所有让 LaunchNow 变得更好的贡献者和翻译者：

- 代码改进与优化 by @dizzycoder1112
- 荷兰语翻译 by @OABsoftware
- 俄语翻译 by @Leoxoo
- 保加利亚语翻译 by Трифон Иванов
- 日语翻译 by @endianoia
- 韩语翻译 by @D-KoLee
- 意大利语和土耳其语翻译 by @wd006

### 📄 许可证

本项目采用 MIT 许可证 — 详情请查看 [LICENSE](LICENSE) 文件。

</details>