# [WakeBar](https://wakebar.ohrats.party)

[![release](https://img.shields.io/github/v/release/OhRats-Technologies/WakeBar?sort=semver&logo=github)](https://github.com/OhRats-Technologies/WakeBar/releases/latest)
[![build](https://img.shields.io/github/actions/workflow/status/OhRats-Technologies/WakeBar/build.yml?branch=main&label=build&logo=github)](https://github.com/OhRats-Technologies/WakeBar/actions/workflows/build.yml)
[![license](https://img.shields.io/badge/license-AGPL--3.0-green.svg)](LICENSE)
[![website](https://img.shields.io/badge/website-wakebar.ohrats.party-purple.svg)](https://wakebar.ohrats.party)
[![support](https://img.shields.io/badge/sponsor-Open%20Collective-blue.svg)](https://opencollective.com/ohrats)

Single-file macOS menu-bar utility for keeping your Mac awake. Handy for long-running builds and remote RC sessions.

![WakeBar](wakebar.png)

## Install

```sh
brew install --cask OhRats-Technologies/tap/wakebar
```

Or download it from [GitHub Releases](../../releases/latest).

## Build

Building from source requires the [Xcode Command Line Tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools).

```sh
xcrun swiftc -parse-as-library WakeBar.swift -o /tmp/WakeBarBuilder
/tmp/WakeBarBuilder --build --run
```

Requires macOS 14 or later.

Licensed under the [GNU AGPL v3](LICENSE).
