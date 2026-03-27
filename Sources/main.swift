import AppKit
import GameController
import CoreGraphics
import os

// MARK: - Logging

private let log = Logger(subsystem: "com.xboxaskeyboard.dpad", category: "main")

// MARK: - Status Bar Icon

enum StatusBarIcon {
    static func create(dotColor: NSColor, enabled: Bool) -> NSImage {
        let width: CGFloat = 24
        let height: CGFloat = 18
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let gamepadColor: NSColor = enabled ? .labelColor : .tertiaryLabelColor
            gamepadColor.setFill()

            NSBezierPath(roundedRect: NSRect(x: 2, y: 4, width: 16, height: 10), xRadius: 3, yRadius: 3).fill()

            NSColor.windowBackgroundColor.setFill()
            NSBezierPath(rect: NSRect(x: 6, y: 7, width: 2, height: 6)).fill()
            NSBezierPath(rect: NSRect(x: 4, y: 9, width: 6, height: 2)).fill()

            let dotSize: CGFloat = 6
            dotColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: width - dotSize - 1, y: 1, width: dotSize, height: dotSize)).fill()

            return true
        }
        image.isTemplate = false
        return image
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var enabledItem: NSMenuItem!
    private var controllerInfoItem: NSMenuItem!
    private var lastInputItem: NSMenuItem!
    private var profileMenuItem: NSMenuItem!
    private var isEnabled: Bool = true
    private let eventSource = CGEventSource(stateID: .hidSystemState)
    private var activityToken: NSObjectProtocol?
    private var appConfig = ConfigStore.load()
    private var settingsController: SettingsWindowController?
    private var flashTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("App launched")
        if eventSource == nil { log.warning("CGEventSource is nil — key simulation will fail") }
        disableAppNap()
        GCController.shouldMonitorBackgroundEvents = true
        setupMenuBar()
        setupControllerNotifications()
        connectExistingControllers()
        checkAccessibilityPermission()
        updateMenuBarIcon()
    }

    // MARK: - App Nap Prevention

    private func disableAppNap() {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Processing controller input for keyboard mapping"
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
        }
    }

    // MARK: - Permissions

    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        log.info("Accessibility permission: \(trusted ? "granted" : "not granted")")
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()

        controllerInfoItem = NSMenuItem(title: "No controller connected", action: nil, keyEquivalent: "")
        controllerInfoItem.isEnabled = false
        menu.addItem(controllerInfoItem)

        profileMenuItem = NSMenuItem(title: profileLabel(), action: nil, keyEquivalent: "")
        profileMenuItem.isEnabled = false
        menu.addItem(profileMenuItem)

        lastInputItem = NSMenuItem(title: "Last input: —", action: nil, keyEquivalent: "")
        lastInputItem.isEnabled = false
        menu.addItem(lastInputItem)

        menu.addItem(.separator())

        enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "e")
        enabledItem.target = self
        enabledItem.state = .on
        menu.addItem(enabledItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateMenuBarIcon() {
        let color = appConfig.activeProfile.color.nsColor
        statusItem.button?.image = StatusBarIcon.create(dotColor: color, enabled: isEnabled)
        statusItem.button?.title = ""
        profileMenuItem.title = profileLabel()
    }

    private func profileLabel() -> String {
        return "\(appConfig.activeProfile.color.emoji) Profile \(appConfig.safeIndex + 1) of \(appConfig.profiles.count)"
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        enabledItem.state = isEnabled ? .on : .off
        updateMenuBarIcon()
        log.info("Mapping \(self.isEnabled ? "enabled" : "disabled")")
    }

    @objc private func openSettings() {
        if let existing = settingsController?.window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = SettingsWindowController(appConfig: appConfig)
        controller.onSave = { [weak self] newConfig in
            guard let self else { return }
            self.appConfig = newConfig
            ConfigStore.save(newConfig)
            self.updateMenuBarIcon()
            for gc in GCController.controllers() {
                self.bindController(gc)
            }
            log.info("Config saved and controllers rebound")
        }
        settingsController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Profile Cycling

    private func cycleProfile() {
        appConfig.cycleProfile()
        ConfigStore.save(appConfig)
        log.info("Switched to profile \(self.appConfig.safeIndex + 1)")

        DispatchQueue.main.async {
            self.updateMenuBarIcon()
            // Flash: briefly show profile name in menu bar
            self.statusItem.button?.title = " Profile \(self.appConfig.safeIndex + 1)"
            self.flashTimer?.invalidate()
            self.flashTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self?.statusItem.button?.title = ""
            }
        }
    }

    // MARK: - Controller

    private func setupControllerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(controllerConnected(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDisconnected(_:)), name: .GCControllerDidDisconnect, object: nil)
        GCController.startWirelessControllerDiscovery {
            log.info("Wireless controller discovery completed")
        }
    }

    private func connectExistingControllers() {
        let controllers = GCController.controllers()
        log.info("Found \(controllers.count) existing controller(s)")
        for controller in controllers {
            bindController(controller)
        }
        updateControllerStatus()
    }

    @objc private func controllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        log.info("Controller connected: \(controller.vendorName ?? "Unknown")")
        bindController(controller)
        updateControllerStatus()
    }

    @objc private func controllerDisconnected(_ notification: Notification) {
        if let controller = notification.object as? GCController {
            log.info("Controller disconnected: \(controller.vendorName ?? "Unknown")")
        }
        updateControllerStatus()
    }

    private func updateControllerStatus() {
        let controllers = GCController.controllers()
        if let first = controllers.first {
            let name = first.vendorName ?? "Controller"
            controllerInfoItem.title = "\(name) — Ready"
        } else {
            controllerInfoItem.title = "No controller connected"
        }
    }

    private func bindController(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else {
            log.warning("Controller has no extendedGamepad, skipping")
            return
        }
        log.info("Binding buttons for: \(controller.vendorName ?? "Unknown")")

        // Bind profile switch button
        switchInput(for: appConfig.switchButton, on: gamepad)?.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            self?.cycleProfile()
        }

        // Map controller buttons to keyboard keys
        let buttonMap: [(GCControllerButtonInput, ControllerButton)] = [
            (gamepad.dpad.up, .dpadUp), (gamepad.dpad.down, .dpadDown),
            (gamepad.dpad.left, .dpadLeft), (gamepad.dpad.right, .dpadRight),
            (gamepad.buttonA, .a), (gamepad.buttonB, .b),
            (gamepad.buttonX, .x), (gamepad.buttonY, .y),
            (gamepad.leftShoulder, .leftBumper), (gamepad.rightShoulder, .rightBumper),
            (gamepad.leftTrigger, .leftTrigger), (gamepad.rightTrigger, .rightTrigger),
        ]
        for (input, button) in buttonMap {
            input.pressedChangedHandler = { [weak self] _, _, pressed in
                self?.handleButton(button, pressed: pressed)
            }
        }
    }

    private func switchInput(for button: SwitchButton, on gamepad: GCExtendedGamepad) -> GCControllerButtonInput? {
        switch button {
        case .menu_: return gamepad.buttonMenu
        case .view_: return gamepad.buttonOptions
        case .home: return gamepad.buttonHome
        }
    }

    // MARK: - Key Simulation

    private func handleButton(_ button: ControllerButton, pressed: Bool) {
        log.debug("\(button.rawValue) \(pressed ? "pressed" : "released")")
        DispatchQueue.main.async {
            self.lastInputItem.title = "Last input: \(button.rawValue) \(pressed ? "↓" : "↑")"
        }
        guard isEnabled, let keyCode = appConfig.activeProfile.keyCode(for: button) else { return }
        postKeyEvent(keyCode: keyCode, keyDown: pressed)
    }

    private func postKeyEvent(keyCode: UInt16, keyDown: Bool) {
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(keyCode), keyDown: keyDown) else {
            log.error("Failed to create CGEvent — check Accessibility permissions")
            return
        }
        event.flags = KeyCodeNames.eventFlags(for: keyCode)
        event.post(tap: .cghidEventTap)
    }
}

// MARK: - Launch

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
