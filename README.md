# WakeBar

Single-file macOS menu-bar utility for keeping your Mac awake.

![WakeBar](wakebar.png)

## Install

Download the latest build from [GitHub Releases](../../releases/latest), unzip it, and move `WakeBar.app` to `/Applications`.

## Build

Building from source requires the [Xcode Command Line Tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools).

```sh
xcrun swiftc -parse-as-library WakeBar.swift -o /tmp/WakeBarBuilder
/tmp/WakeBarBuilder --build --run
```

Requires macOS 14 or later.

Licensed under the [GNU AGPL v3](LICENSE).
