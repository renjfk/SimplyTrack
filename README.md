# SimplyTrack

A simple, elegant macOS productivity tracking app that helps you monitor your application and website usage patterns.

![Demo Video](Screenshots/Screen_Recording.mov)
![Screenshot 1](Screenshots/Screenshot_1.png)
![Screenshot 2](Screenshots/Screenshot_2.png)
![Screenshot 3](Screenshots/Screenshot_3.png)

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

- **📊 App & Website Tracking** - Monitor time spent in applications and websites
- **📈 Visual Analytics** - Charts showing daily/weekly activity patterns
- **🔒 Privacy-First** - All data stored locally, no cloud sync
- **🚀 Menu Bar Interface** - Clean popover UI, native macOS integration
- **⚡ Smart Detection** - Automatic idle detection and session management

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
    - Enable SimplyTrack for your browsers

2. **Notifications** (Optional): For update notifications
    - System Preferences → Notifications & Focus → SimplyTrack

### Permission Setup

The app provides helpful banners and direct links to the appropriate system preference panes when permissions are
needed.

## TODO

- [ ] **Unit Tests**: Comprehensive test coverage for core functionality
- [ ] **UI Tests**: Automated UI testing for user interactions

## Contributing

SimplyTrack is open to contributions and ideas! Whether you're a developer wanting to add features or a user with
suggestions, your input is valuable.

## License

This project is licensed under the [MIT License](LICENSE).
