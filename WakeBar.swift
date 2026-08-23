// WakeBar — single-file macOS menu-bar app.
// Copyright © 2026 OhRats Technologies.
// SPDX-License-Identifier: AGPL-3.0-only
// https://ohrats.party
// Build and run:
// xcrun swiftc -parse-as-library WakeBar.swift -o /tmp/WakeBarBuilder && /tmp/WakeBarBuilder --build --run

import SwiftUI
import AppKit
import ServiceManagement
import Darwin

@main
enum WakeBarMain {
    static func main() {
        if CommandLine.arguments.contains("--build") {
            do { try AppBuilder.build(openAfter: CommandLine.arguments.contains("--run")) }
            catch {
                FileHandle.standardError.write(Data("Build failed: \(error.localizedDescription)\n".utf8))
                Darwin.exit(1)
            }
        } else {
            WakeBarApp.main()
        }
    }
}

enum AppBuilder {
    static func build(openAfter: Bool) throws {
        let fm = FileManager.default
        let source = URL(fileURLWithPath: #filePath)
        let root = source.deletingLastPathComponent()
        let app = root.appendingPathComponent("dist/WakeBar.app")
        let contents = app.appendingPathComponent("Contents")
        let executable = contents.appendingPathComponent("MacOS/WakeBar")
        let arm64 = contents.appendingPathComponent("MacOS/WakeBar-arm64")
        let x86_64 = contents.appendingPathComponent("MacOS/WakeBar-x86_64")

        NSRunningApplication.runningApplications(withBundleIdentifier: "party.ohrats.WakeBar")
            .forEach { $0.terminate() }
        Thread.sleep(forTimeInterval: 0.4)
        if fm.fileExists(atPath: app.path) { try fm.removeItem(at: app) }
        try fm.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: contents.appendingPathComponent("Resources"), withIntermediateDirectories: true)

        let common = [
            "swiftc", "-parse-as-library", "-O",
            "-framework", "SwiftUI", "-framework", "AppKit", "-framework", "ServiceManagement",
        ]
        try command("/usr/bin/xcrun", common + [
            "-target", "arm64-apple-macos14.0", source.path, "-o", arm64.path
        ])
        try command("/usr/bin/xcrun", common + [
            "-target", "x86_64-apple-macos14.0", source.path, "-o", x86_64.path
        ])
        try command("/usr/bin/xcrun", [
            "lipo", "-create", arm64.path, x86_64.path, "-output", executable.path
        ])
        try fm.removeItem(at: arm64)
        try fm.removeItem(at: x86_64)
        try infoPlist.write(to: contents.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        try command("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", app.path])
        print("Built \(app.path)")
        if openAfter { try command("/usr/bin/open", [app.path]) }
    }

    private static func command(_ path: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "WakeBarBuilder", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(path) exited with status \(process.terminationStatus)"])
        }
    }

    private static var infoPlist: String {
        let environment = ProcessInfo.processInfo.environment
        let version = environment["WAKEBAR_VERSION"] ?? "1.0"
        let build = environment["WAKEBAR_BUILD"] ?? "1"
        return """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>CFBundleExecutable</key><string>WakeBar</string>
      <key>CFBundleIdentifier</key><string>party.ohrats.WakeBar</string>
      <key>CFBundleName</key><string>WakeBar</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>CFBundleShortVersionString</key><string>\(version)</string>
      <key>CFBundleVersion</key><string>\(build)</string>
      <key>NSHumanReadableCopyright</key><string>Copyright © 2026 OhRats Technologies.</string>
      <key>LSMinimumSystemVersion</key><string>14.0</string>
      <key>LSUIElement</key><true/>
      <key>NSPrincipalClass</key><string>NSApplication</string>
    </dict></plist>
    """
    }
}

enum SleepSettings {
    static func flags(idle: Bool, display: Bool, disk: Bool, systemOnAC: Bool) -> String {
        (idle ? "i" : "") + (display ? "d" : "") + (disk ? "m" : "") + (systemOnAC ? "s" : "")
    }

    static func lidCloseEnabled(in output: String) -> Bool {
        output.split(separator: "\n").contains {
            $0.split(whereSeparator: \.isWhitespace).joined(separator: " ")
                .caseInsensitiveCompare("SleepDisabled 1") == .orderedSame
        }
    }
}

struct WakeBarApp: App {
    @StateObject private var model = WakeModel()

    var body: some Scene {
        MenuBarExtra {
            WakeMenu(model: model)
        } label: {
            StatusIcon(active: model.isActive, lidClose: model.lidCloseEnabled)
        }
        .menuBarExtraStyle(.menu)

        Window("About WakeBar", id: "about") { AboutView() }
            .windowResizability(.contentSize)
            .defaultPosition(.center)
    }
}

struct WakeMenu: View {
    @ObservedObject var model: WakeModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Sleep Prevention", isOn: Binding(get: { model.isActive }, set: model.setActive))
        Menu("Sleep Options") {
            Toggle("Prevent Idle System Sleep", isOn: $model.preventIdle)
            Toggle("Prevent Display Sleep", isOn: $model.preventDisplay)
            Toggle("Prevent Disk Idle", isOn: $model.preventDisk)
            Toggle("Prevent System Sleep on AC Power", isOn: $model.preventSystemOnAC)
        }
        Divider()
        if model.helperInstalled {
            Toggle("Keep Awake With Lid Closed", isOn: Binding(get: { model.lidCloseEnabled }, set: model.setLidClose))
        } else {
            Button("Enable Lid-Close Control…", action: model.installHelper)
        }
        Toggle("Open at Login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
        Divider()
        Button("About WakeBar") {
            openWindow(id: "about")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Button("Quit WakeBar") { NSApplication.shared.terminate(nil) }
    }
}

private struct StatusIcon: View {
    let active: Bool
    let lidClose: Bool

    var body: some View {
        Image(nsImage: image)
            .accessibilityLabel(lidClose ? "WakeBar: lid-close prevention enabled" :
                                active ? "WakeBar: sleep prevention enabled" : "WakeBar: sleep prevention off")
    }

    private var image: NSImage {
        let canvas = NSSize(width: lidClose ? 28 : 20, height: 18)
        let result = NSImage(size: canvas, flipped: false) { _ in
            let cup = NSImage(systemSymbolName: active || lidClose ? "cup.and.saucer.fill" : "cup.and.saucer",
                              accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
            cup?.draw(in: NSRect(x: 0, y: 1, width: 19, height: 16))
            if lidClose {
                let lock = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?
                    .withSymbolConfiguration(.init(pointSize: 9, weight: .semibold))
                lock?.draw(in: NSRect(x: 19, y: 3, width: 9, height: 11))
            }
            return true
        }
        result.isTemplate = true
        return result
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("WakeBar").font(.headline)
            Text("Version \(version) (\(build))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Divider().padding(.vertical, 3)
            Text("Copyright © 2026 OhRats Technologies.")
                .font(.caption)
            Text("GNU Affero General Public License v3.0")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("ohrats.party")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }

    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
    private var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1" }
}

@MainActor
final class WakeModel: ObservableObject {
    @Published var isActive = false
    @Published var preventIdle: Bool { didSet { changed("preventIdle", preventIdle) } }
    @Published var preventDisplay: Bool { didSet { changed("preventDisplay", preventDisplay) } }
    @Published var preventDisk: Bool { didSet { changed("preventDisk", preventDisk) } }
    @Published var preventSystemOnAC: Bool { didSet { changed("preventSystemOnAC", preventSystemOnAC) } }
    @Published var lidCloseEnabled = false
    @Published var helperInstalled = false
    @Published var launchAtLogin = false

    private let defaults = UserDefaults.standard
    private var caffeinate: Process?
    private let helper = "/usr/local/libexec/wakebar-pmset"
    private let sudoers = "/etc/sudoers.d/wakebar-pmset"

    init() {
        let resume = defaults.object(forKey: "sleepPreventionEnabled") as? Bool ?? false
        preventIdle = defaults.object(forKey: "preventIdle") as? Bool
            ?? defaults.object(forKey: "preventIdleSystemSleep") as? Bool ?? true
        preventDisplay = defaults.object(forKey: "preventDisplay") as? Bool
            ?? defaults.object(forKey: "preventDisplaySleep") as? Bool ?? false
        preventDisk = defaults.object(forKey: "preventDisk") as? Bool
            ?? defaults.object(forKey: "preventDiskIdle") as? Bool ?? false
        preventSystemOnAC = defaults.object(forKey: "preventSystemOnAC") as? Bool
            ?? defaults.object(forKey: "preventSystemSleep") as? Bool ?? false
        if defaults.bool(forKey: "wantsLaunchAtLogin"), SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
        refresh()
        if lidCloseEnabled || resume { applyActive(true) }
    }

    func setActive(_ enabled: Bool) {
        if !enabled, lidCloseEnabled, !applyLidClose(false) { return }
        applyActive(enabled)
    }

    func setLidClose(_ enabled: Bool) {
        let wasActive = isActive
        if enabled && !wasActive { applyActive(true) }
        if !applyLidClose(enabled), !wasActive { applyActive(false) }
    }

    private func applyActive(_ enabled: Bool) {
        defaults.set(enabled, forKey: "sleepPreventionEnabled")
        if enabled {
            guard !isActive || caffeinate?.isRunning != true else { return }
            if !preventIdle && !preventDisplay && !preventDisk && !preventSystemOnAC { preventIdle = true }
            isActive = true
            startCaffeinate()
        } else {
            let process = caffeinate
            caffeinate = nil
            process?.terminationHandler = nil
            process?.terminate()
            isActive = false
        }
    }

    private func startCaffeinate() {
        let flags = SleepSettings.flags(idle: preventIdle, display: preventDisplay,
                                        disk: preventDisk, systemOnAC: preventSystemOnAC)
        guard !flags.isEmpty else { isActive = false; return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-" + flags, "-w", String(ProcessInfo.processInfo.processIdentifier)]
        process.terminationHandler = { [weak self] finished in
            Task { @MainActor [weak self] in
                guard let self, self.caffeinate === finished else { return }
                self.caffeinate = nil
                self.isActive = false
                self.defaults.set(false, forKey: "sleepPreventionEnabled")
            }
        }
        do { caffeinate = process; try process.run() }
        catch { caffeinate = nil; isActive = false; alert("Could not start caffeinate: \(error.localizedDescription)") }
    }

    private func changed(_ key: String, _ value: Bool) {
        defaults.set(value, forKey: key)
        guard isActive else { return }
        let old = caffeinate
        caffeinate = nil
        old?.terminationHandler = nil
        old?.terminate()
        isActive = true
        startCaffeinate()
    }

    @discardableResult
    private func applyLidClose(_ enabled: Bool) -> Bool {
        guard helperInstalled else { alert("Lid-close control needs its privileged helper reinstalled."); return false }
        let result = run("/usr/bin/sudo", ["-n", helper, enabled ? "on" : "off"])
        if result.status == 0 { lidCloseEnabled = enabled; return true }
        lidCloseEnabled = readLidState()
        alert(result.output.isEmpty ? "Lid-close control could not be changed." : result.output)
        return false
    }

    func installHelper() {
        let helperText = """
        #!/bin/sh
        set -eu
        case "${1:-}" in
          on) exec /usr/bin/pmset -a disablesleep 1 ;;
          off) exec /usr/bin/pmset -a disablesleep 0 ;;
          *) echo "Usage: wakebar-pmset on|off" >&2; exit 64 ;;
        esac
        """
        let rule = "\(NSUserName()) ALL=(root) NOPASSWD: \(helper) on, \(helper) off\n"
        let h64 = Data(helperText.utf8).base64EncodedString(), r64 = Data(rule.utf8).base64EncodedString()
        let command = "mkdir -p /usr/local/libexec && printf %s \(h64) | /usr/bin/base64 -D > \(helper) && chmod 755 \(helper) && printf %s \(r64) | /usr/bin/base64 -D > \(sudoers) && chmod 440 \(sudoers) && /usr/sbin/visudo -cf \(sudoers)"
        var error: NSDictionary?
        let script = NSAppleScript(source: "do shell script \"\(command)\" with administrator privileges")
        if script?.executeAndReturnError(&error) != nil, error == nil { refresh() }
        else { alert(error?[NSAppleScript.errorMessage] as? String ?? "Helper installation was cancelled.") }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            defaults.set(enabled, forKey: "wantsLaunchAtLogin")
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if enabled && !launchAtLogin { alert("Approve WakeBar in System Settings › General › Login Items.") }
        } catch { launchAtLogin = SMAppService.mainApp.status == .enabled; alert(error.localizedDescription) }
    }

    private func refresh() {
        helperInstalled = secure(helper, executable: true) && secure(sudoers, executable: false)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        lidCloseEnabled = readLidState()
    }

    private func readLidState() -> Bool { SleepSettings.lidCloseEnabled(in: run("/usr/bin/pmset", ["-g"]).output) }

    private func secure(_ path: String, executable: Bool) -> Bool {
        guard let a = try? FileManager.default.attributesOfItem(atPath: path),
              (a[.ownerAccountID] as? NSNumber)?.intValue == 0,
              let p = (a[.posixPermissions] as? NSNumber)?.intValue, p & 0o022 == 0 else { return false }
        return !executable || FileManager.default.isExecutableFile(atPath: path)
    }

    private func run(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments
        process.standardOutput = pipe; process.standardError = pipe
        do { try process.run(); process.waitUntilExit() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    private func alert(_ text: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning; alert.messageText = "WakeBar couldn’t complete that action"
        alert.informativeText = text; alert.addButton(withTitle: "OK")
        NSApplication.shared.activate(ignoringOtherApps: true); alert.runModal()
    }
}
