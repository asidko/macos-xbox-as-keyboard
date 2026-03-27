import AppKit
import GameController
import CoreGraphics
import os

// MARK: - Logging

private let log = Logger(subsystem: "com.xboxaskeyboard.dpad", category: "main")

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var enabledItem: NSMenuItem!
    private var controllerInfoItem: NSMenuItem!
    private var lastInputItem: NSMenuItem!
    private var isEnabled: Bool = true
    private let eventSource = CGEventSource(stateID: .hidSystemState)
    private var activityToken: NSObjectProtocol?
    private var config = ConfigStore.load()
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("App launched")
        if eventSource == nil { log.warning("CGEventSource is nil — key simulation will fail") }
        disableAppNap()
        GCController.shouldMonitorBackgroundEvents = true
        setupMenuBar()
        setupControllerNotifications()
        connectExistingControllers()
        checkAccessibilityPermission()
    }

    // MARK: - App Nap Prevention

    private func disableAppNap() {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Processing controller input for keyboard mapping"
        )
        log.info("App Nap disabled")
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
        statusItem.button?.title = "🎮"

        let menu = NSMenu()

        controllerInfoItem = NSMenuItem(title: "No controller connected", action: nil, keyEquivalent: "")
        controllerInfoItem.isEnabled = false
        menu.addItem(controllerInfoItem)

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

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        enabledItem.state = isEnabled ? .on : .off
        statusItem.button?.title = isEnabled ? "🎮" : "🎮✗"
        log.info("Mapping \(self.isEnabled ? "enabled" : "disabled")")
    }

    @objc private func openSettings() {
        if let existing = settingsController?.window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = SettingsWindowController(config: config)
        controller.onSave = { [weak self] newConfig in
            guard let self else { return }
            self.config = newConfig
            ConfigStore.save(newConfig)
            // Rebind all connected controllers with new mappings
            for gc in GCController.controllers() {
                self.bindController(gc)
            }
            log.info("Config updated and controllers rebound")
        }
        settingsController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Controller

    private func setupControllerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(controllerConnected(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDisconnected(_:)), name: .GCControllerDidDisconnect, object: nil)
        GCController.startWirelessControllerDiscovery {
            log.info("Wireless controller discovery completed")
        }
        log.info("Listening for controllers (backgroundEvents=true)")
    }

    private func connectExistingControllers() {
        let controllers = GCController.controllers()
        log.info("Found \(controllers.count) existing controller(s)")
        for controller in controllers {
            bindController(controller)
        }
        updateStatus()
    }

    @objc private func controllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        log.info("Controller connected: \(controller.vendorName ?? "Unknown")")
        bindController(controller)
        updateStatus()
    }

    @objc private func controllerDisconnected(_ notification: Notification) {
        if let controller = notification.object as? GCController {
            log.info("Controller disconnected: \(controller.vendorName ?? "Unknown")")
        }
        updateStatus()
    }

    private func updateStatus() {
        let controllers = GCController.controllers()
        if let first = controllers.first {
            let name = first.vendorName ?? "Controller"
            let hasGamepad = first.extendedGamepad != nil
            controllerInfoItem.title = "\(name) — \(hasGamepad ? "Ready" : "No gamepad profile")"
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

        // D-pad
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.dpadUp, pressed: pressed)
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.dpadDown, pressed: pressed)
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.dpadLeft, pressed: pressed)
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.dpadRight, pressed: pressed)
        }

        // Face buttons
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.a, pressed: pressed)
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.b, pressed: pressed)
        }
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.x, pressed: pressed)
        }
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.y, pressed: pressed)
        }

        // Bumpers
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.leftBumper, pressed: pressed)
        }
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.rightBumper, pressed: pressed)
        }

        // Triggers
        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.leftTrigger, pressed: pressed)
        }
        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.handleButton(.rightTrigger, pressed: pressed)
        }
    }

    // MARK: - Key Simulation

    private func handleButton(_ button: ControllerButton, pressed: Bool) {
        log.debug("\(button.rawValue) \(pressed ? "pressed" : "released")")
        DispatchQueue.main.async {
            self.lastInputItem.title = "Last input: \(button.rawValue) \(pressed ? "↓" : "↑")"
        }
        guard isEnabled, let keyCode = config.keyCode(for: button) else { return }
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
