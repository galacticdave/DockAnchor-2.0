# DockAnchor

**Keep your macOS Dock exactly where you want it.**

DockAnchor is a lightweight macOS utility that prevents the Dock from "jumping" between screens in multi-monitor setups. It locks the Dock to a specific monitor and intelligently remembers your preferences for different environments (e.g., Home vs. Office).

> **Fork Note:** This is a modernized fork of the original [DockAnchor by bwya77](https://github.com/bwya77/DockAnchor). It adds hardware-level fingerprinting, environment collections, and Apple Silicon optimization.

---

## ✨ New Features in v2.0

### 🖥️ Hardware-Level Fingerprinting
Gone are the days of the Dock jumping because macOS confused two identical monitors. DockAnchor now identifies displays by their **Physical Serial Number** and **UUID**, ensuring rock-solid stability even if you swap ports.

### 🌍 Environment Collections
DockAnchor automatically detects where you are:
* **At Home?** It anchors to your ultrawide gaming monitor.
* **At Work?** It anchors to your center Dell monitor.
* **On the Go?** It defaults to your MacBook's built-in display.
* *No manual switching required.*

### 🔓 "Hold Option" to Unlock
Need the Dock on a different screen for just a second?
* **Hold the `Option (⌥)` key** and move your mouse to the bottom of any screen.
* The Dock will behave normally.
* Release the key, and the anchor re-engages immediately.

---

## 🚀 Installation & Permissions

### 1. Download
Download the latest release from the [Releases Page](#).

### 2. First Run (Critical)
When you first open DockAnchor, you will see a **Permissions Required** screen.
1.  Click **"Open System Settings"**.
2.  Enable the switch for **DockAnchor**.
3.  The app will detect the change and launch automatically.

> **Why is this needed?**
> DockAnchor uses a global event tap to monitor mouse movements and the `Option` key. macOS requires Accessibility permissions for any app that intercepts these events. **No data is recorded or transmitted.**

---

## ⚙️ Configuration

The app runs silently in your Menu Bar.

* **Set Anchor:** Move your mouse to the desired screen, click the menu bar icon, and select **"Set Anchor to Current Screen"**.
* **Start/Stop:** Quickly toggle protection if you need to disable it temporarily.
* **Hide Icon:** You can hide the menu bar icon in Settings. (Relaunch the app from Applications to bring it back).

---

## 🛠️ Building from Source

**Requirements:**
* Xcode 14.0+
* macOS 13.0+ (Ventura or newer)
* Swift 5.0

**Steps:**
1.  Clone the repository.
2.  Open `DockAnchor.xcodeproj` in Xcode.
3.  Ensure Signing & Capabilities are set to your development team.
4.  Build and Run.

*Note: If building from Xcode, you may need to reset permissions if the app doesn't appear in System Settings:*
```bash
tccutil reset Accessibility com.yourname.DockAnchor

🤝 Credits & License
This project is an open-source fork based on the excellent work by bwya77.

Original Author: Bradley Wyatt (bwya77)

Original Repository: DockAnchor v1.5

License: MIT License (See LICENSE file)

We have maintained the original MIT license to ensure this tool remains free and open for the macOS community.