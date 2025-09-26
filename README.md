[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/renjfk/SimplyTrack)](https://github.com/renjfk/SimplyTrack/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/renjfk/SimplyTrack/total)](https://github.com/renjfk/SimplyTrack/releases)

<p align="center">
 <img width="200" alt="SimplyTrack Icon" src="SimplyTrack/Assets.xcassets/AppIcon.appiconset/icon_512x512%402x.png">
</p>

# SimplyTrack

A simple, elegant macOS productivity tracking app that helps you monitor your application and website usage patterns.

| App Overview | MCP Demo with Claude Desktop |
|:---:|:---:|
| ![App Overview](Screenshots/Screen_recording_1.gif) | ![MCP Demo with Claude Desktop](Screenshots/Screen_recording_2.gif) |

| Daily Activity View with Bar Chart | Daily Activity View with Pie Chart |
|:---:|:---:|
| ![Daily Activity View](Screenshots/Screenshot_1.png) | ![Daily Pie Chart View](Screenshots/Screenshot_2.png) |

| Weekly Activity Overview | AI-Powered Usage Summary Notifications |
|:---:|:---:|
| ![Weekly Activity View](Screenshots/Screenshot_3.png) | ![Usage Summary Notification 1](Screenshots/Screenshot_4.png)<br>![Usage Summary Notification 2](Screenshots/Screenshot_5.png) |

## Motivation

I created SimplyTrack out of a personal need to understand and improve my productivity. Like many developers and
professionals, I wanted to track my app and website usage to identify patterns, time-wasters, and productivity trends.

After trying several existing solutions, I found they were either:

- **Too complex** - Loaded with features I didn't need
- **Too limited** - Missing key functionality I required
- **Too expensive** - Overkill for simple usage tracking
- **Privacy concerns** - Sending data to external servers

So I decided to build exactly what I needed: a clean, privacy-focused, local-only productivity tracker that gives you
insights without the bloat.

## ✨ Features

- **📊 App & Website Tracking** - Monitor time spent in applications and websites (Safari, Chrome, Edge supported)
- **📈 Visual Analytics** - Charts showing daily/weekly activity patterns
- **🔔 Smart Notifications** - Optional AI-powered daily summary notifications with usage insights
- **🤖 AI Integration** - Built-in MCP server for seamless integration with Claude and other AI assistants
- **🔒 Privacy-First** - All data stored locally, secure keychain storage for API keys, optional private browsing tracking
- **🚀 Menu Bar Interface** - Clean popover UI, native macOS integration
- **🔍 Smart Detection** - Automatic idle detection, session management, and private browsing detection

## 🛠️ Installation

### Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac

### Download

**[⬇️ Download SimplyTrack.dmg](https://github.com/renjfk/SimplyTrack/releases/latest/download/SimplyTrack.dmg)**

Or manually:

1. Go to the [Releases](https://github.com/renjfk/SimplyTrack/releases) page
2. Download the latest `SimplyTrack.dmg` file
3. Open the DMG and drag SimplyTrack to your Applications folder
4. Launch SimplyTrack and follow the permission setup guide

### Building from Source

```bash
git clone https://github.com/renjfk/SimplyTrack.git
cd SimplyTrack
open SimplyTrack.xcodeproj
```

Build and run in Xcode 15.0 or later.

## Setup & Permissions

SimplyTrack requires several macOS permissions to function properly:

### Required Permissions

1. **Automation Permission**: To track browser activity
    - System Preferences → Privacy & Security → Automation
    - Enable SimplyTrack for your browsers (Safari, Chrome, Edge)

2. **System Events Permission**: For Safari private browsing detection
    - System Preferences → Privacy & Security → Automation
    - Enable SimplyTrack for System Events

3. **Accessibility Permission**: For Safari private browsing detection
    - System Preferences → Privacy & Security → Accessibility
    - Enable SimplyTrack

4. **Notifications** (Optional): For update notifications
    - System Preferences → Notifications & Focus → SimplyTrack

### Permission Setup

The app provides helpful banners and direct links to the appropriate system preference panes when permissions are
needed.

## 🤖 AI Integration (MCP)

SimplyTrack includes a built-in **Model Context Protocol (MCP) server** that allows AI assistants like Claude to access your usage data for insights and analysis.

### Features

- **Usage Data Access**: AI assistants can retrieve your app/website usage statistics
- **Smart Analysis**: Get personalized productivity insights from your data
- **Privacy-Focused**: Data never leaves your machine - AI connects directly to your local SimplyTrack instance
- **Easy Setup**: One-click configuration for Claude Desktop

### Setup with Claude Desktop

1. Open SimplyTrack Settings → AI tab
2. In the "AI Tool Integration" section, click **"Auto-Configure"**
3. Select your Claude Desktop configuration file when prompted
4. Restart Claude Desktop to activate the integration

### Available Tools

- **`get_usage_activity`** - Retrieve detailed usage statistics for any date
  - Filter by applications or websites
  - Customize time ranges and top activity percentages
  - Get formatted data perfect for AI analysis

### Example Usage

Ask Claude: *"What were my top 3 most used apps yesterday?"* or *"Analyze my productivity patterns this week"*

The MCP server provides real-time access to your usage data while maintaining complete privacy and control.

## Contributing

SimplyTrack is open to contributions and ideas! Whether you're a developer wanting to add features or a user with
suggestions, your input is valuable.

### Issue Conventions

When creating issues, please follow our simple naming convention:

**Format:** `type: brief description`

#### Issue Types

- `feat:` - New features or functionality
- `fix:` - Bug fixes  
- `enhance:` - Improvements to existing features
- `chore:` - Maintenance tasks, dependencies, cleanup
- `docs:` - Documentation updates
- `build:` - Build system, CI/CD changes

#### Examples

- `feat: add CSV export functionality`
- `fix: app crashes when importing large files`
- `enhance: improve data loading performance`
- `chore: update dependencies to latest versions`
- `docs: update README with installation instructions`
- `build: update Xcode project settings`

#### Guidelines

- Use lowercase for the description
- Be specific and actionable
- Keep under 60 characters
- No period at the end

## Development

### Release Process

Manual releases with GitHub MCP integration - see [RELEASE_PROCESS.md](RELEASE_PROCESS.md).

For planned improvements and testing infrastructure, see [issue #9](https://github.com/renjfk/SimplyTrack/issues/9).

## License

This project is licensed under the [MIT License](LICENSE).