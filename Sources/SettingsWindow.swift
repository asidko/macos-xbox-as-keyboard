import AppKit
import Carbon.HIToolbox

// MARK: - Key Capture Button

final class KeyCaptureButton: NSButton {
    var keyCode: UInt16?
    var onCapture: ((UInt16) -> Void)?
    private var isCapturing = false
    private var localMonitor: Any?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(startCapture)
        updateTitle()
    }

    func updateTitle() {
        title = keyCode.map { KeyCodeNames.name(for: $0) } ?? "Not Set"
    }

    @objc private func startCapture() {
        isCapturing = true
        title = "Press a key..."

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isCapturing else { return event }
            self.stopCapture()
            self.keyCode = event.keyCode
            self.updateTitle()
            self.onCapture?(event.keyCode)
            return nil
        }
    }

    private func stopCapture() {
        isCapturing = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit { stopCapture() }
}

// MARK: - Mapping Action Handler

/// Handles dropdown selection and clear for a single button mapping row.
/// Uses profile ID (not index) so it survives tab rebuilds.
private final class MappingActionHandler: NSObject {
    let profileId: UUID
    let button: ControllerButton
    weak var captureBtn: KeyCaptureButton?
    weak var dropdown: NSPopUpButton?
    weak var controller: SettingsWindowController?

    init(profileId: UUID, button: ControllerButton, captureBtn: KeyCaptureButton, dropdown: NSPopUpButton, controller: SettingsWindowController) {
        self.profileId = profileId
        self.button = button
        self.captureBtn = captureBtn
        self.dropdown = dropdown
        self.controller = controller
    }

    fileprivate func profileIndex() -> Int? {
        controller?.appConfig.profiles.firstIndex(where: { $0.id == profileId })
    }

    @objc func dropdownChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx > 0, let profileIdx = profileIndex() else { return }
        let keyCode = allKeys[idx - 1].keyCode
        controller?.appConfig.profiles[profileIdx].setKeyCode(keyCode, for: button)
        captureBtn?.keyCode = keyCode
        captureBtn?.updateTitle()
    }

    @objc func clear() {
        guard let profileIdx = profileIndex() else { return }
        controller?.appConfig.profiles[profileIdx].setKeyCode(nil, for: button)
        captureBtn?.keyCode = nil
        captureBtn?.updateTitle()
        dropdown?.selectItem(at: 0)
    }
}

// MARK: - Settings Window Controller

final class SettingsWindowController: NSWindowController {
    var appConfig: AppConfig
    var onSave: ((AppConfig) -> Void)?
    private var tabView: NSTabView!
    private var switchPopup: NSPopUpButton!

    init(appConfig: AppConfig) {
        self.appConfig = appConfig
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 660),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI Construction

    private func buildUI() {
        guard let window else { return }

        let width: CGFloat = 520
        let totalHeight: CGFloat = 660
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: totalHeight))
        var y: CGFloat = 16

        // Save button
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(saveConfig))
        saveBtn.frame = NSRect(x: width - 100, y: y, width: 80, height: 32)
        saveBtn.keyEquivalent = "\r"
        contentView.addSubview(saveBtn)
        y += 44

        addSeparator(to: contentView, at: y, width: width)
        y += 16

        // Profile switch button
        let switchLabel = NSTextField(labelWithString: "Switch profiles:")
        switchLabel.frame = NSRect(x: 20, y: y + 2, width: 110, height: 20)
        switchLabel.alignment = .right
        switchLabel.font = NSFont.systemFont(ofSize: 13)
        contentView.addSubview(switchLabel)

        switchPopup = NSPopUpButton(frame: NSRect(x: 140, y: y, width: 160, height: 26), pullsDown: false)
        for btn in SwitchButton.allCases {
            switchPopup.addItem(withTitle: btn.rawValue)
        }
        let selectedIdx = SwitchButton.allCases.firstIndex(of: appConfig.switchButton) ?? 0
        switchPopup.selectItem(at: selectedIdx)
        switchPopup.target = self
        switchPopup.action = #selector(switchButtonChanged)
        contentView.addSubview(switchPopup)
        y += 38

        addSeparator(to: contentView, at: y, width: width)
        y += 8

        // Tab view
        let tabHeight = totalHeight - y - 10
        tabView = NSTabView(frame: NSRect(x: 10, y: y, width: width - 20, height: tabHeight))
        contentView.addSubview(tabView)

        for index in appConfig.profiles.indices {
            addTab(for: index)
        }
        if appConfig.safeIndex < tabView.numberOfTabViewItems {
            tabView.selectTabViewItem(at: appConfig.safeIndex)
        }

        window.contentView = contentView
    }

    private func addSeparator(to view: NSView, at y: CGFloat, width: CGFloat) {
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: 20, y: y, width: width - 40, height: 1)
        view.addSubview(sep)
    }

    private func addTab(for profileIndex: Int) {
        let profile = appConfig.profiles[profileIndex]
        let item = NSTabViewItem(identifier: profile.id)
        item.label = "\(profile.color.emoji) Profile \(profileIndex + 1)"
        item.view = buildMappingView(for: profile.id)
        tabView.addTabViewItem(item)
    }

    private func buildMappingView(for profileId: UUID) -> NSView {
        let width: CGFloat = 480
        let view = NSView()
        var y: CGFloat = 8

        // Profile management
        let dupBtn = NSButton(title: "+ New profile", target: self, action: #selector(duplicateCurrentProfile))
        dupBtn.frame = NSRect(x: 10, y: y, width: 120, height: 26)
        view.addSubview(dupBtn)

        if appConfig.profiles.count > 1 {
            let delBtn = NSButton(title: "Delete", target: self, action: #selector(deleteCurrentProfile))
            delBtn.frame = NSRect(x: 138, y: y, width: 70, height: 26)
            view.addSubview(delBtn)

            let moveLeftBtn = NSButton(title: "◀", target: self, action: #selector(moveProfileLeft))
            moveLeftBtn.frame = NSRect(x: width - 70, y: y, width: 30, height: 26)
            view.addSubview(moveLeftBtn)

            let moveRightBtn = NSButton(title: "▶", target: self, action: #selector(moveProfileRight))
            moveRightBtn.frame = NSRect(x: width - 36, y: y, width: 30, height: 26)
            view.addSubview(moveRightBtn)
        }

        y += 36

        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: 10, y: y, width: width - 20, height: 1)
        view.addSubview(sep)
        y += 12

        // Mapping rows: label | [Record] | [Dropdown] | [✕]
        let profileIdx = appConfig.profiles.firstIndex(where: { $0.id == profileId })

        for button in ControllerButton.allCases.reversed() {
            let label = NSTextField(labelWithString: button.rawValue)
            label.frame = NSRect(x: 4, y: y + 3, width: 70, height: 18)
            label.alignment = .right
            label.font = NSFont.systemFont(ofSize: 12)
            view.addSubview(label)

            let captureBtn = KeyCaptureButton(frame: NSRect(x: 80, y: y, width: 100, height: 26))
            if let idx = profileIdx {
                captureBtn.keyCode = appConfig.profiles[idx].keyCode(for: button)
            }
            captureBtn.updateTitle()
            view.addSubview(captureBtn)

            let dropdown = NSPopUpButton(frame: NSRect(x: 186, y: y, width: 200, height: 26), pullsDown: false)
            dropdown.addItem(withTitle: "— Select key —")
            for key in allKeys { dropdown.addItem(withTitle: key.name) }
            if let kc = captureBtn.keyCode, let match = allKeys.firstIndex(where: { $0.keyCode == kc }) {
                dropdown.selectItem(at: match + 1)
            }
            view.addSubview(dropdown)

            let clearBtn = NSButton(title: "✕", target: nil, action: nil)
            clearBtn.bezelStyle = .rounded
            clearBtn.frame = NSRect(x: 392, y: y, width: 30, height: 26)
            view.addSubview(clearBtn)

            // Single handler for dropdown + clear + record sync
            let handler = MappingActionHandler(profileId: profileId, button: button, captureBtn: captureBtn, dropdown: dropdown, controller: self)

            captureBtn.onCapture = { [weak handler, weak dropdown] keyCode in
                guard let handler else { return }
                if let idx = handler.profileIndex() {
                    handler.controller?.appConfig.profiles[idx].setKeyCode(keyCode, for: button)
                }
                if let match = allKeys.firstIndex(where: { $0.keyCode == keyCode }) {
                    dropdown?.selectItem(at: match + 1)
                } else {
                    dropdown?.selectItem(at: 0)
                }
            }

            dropdown.target = handler
            dropdown.action = #selector(MappingActionHandler.dropdownChanged(_:))

            clearBtn.target = handler
            clearBtn.action = #selector(MappingActionHandler.clear)

            // Keep handler alive
            objc_setAssociatedObject(dropdown, "handler", handler, .OBJC_ASSOCIATION_RETAIN)

            y += 32
        }

        y += 4
        let hint = NSTextField(labelWithString: "Record a key or select from dropdown. ✕ to clear.")
        hint.frame = NSRect(x: 10, y: y, width: width - 20, height: 16)
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        view.addSubview(hint)
        y += 24

        view.frame = NSRect(x: 0, y: 0, width: width, height: y)
        return view
    }

    // MARK: - Actions

    @objc private func saveConfig() {
        onSave?(appConfig)
        window?.close()
    }

    @objc private func switchButtonChanged() {
        appConfig.switchButton = SwitchButton.allCases[switchPopup.indexOfSelectedItem]
    }

    @objc private func duplicateCurrentProfile() {
        let currentIndex = tabView.indexOfTabViewItem(tabView.selectedTabViewItem!)
        let newIndex = appConfig.duplicateProfile(at: currentIndex)
        rebuildTabs()
        tabView.selectTabViewItem(at: newIndex)
    }

    @objc private func deleteCurrentProfile() {
        guard appConfig.profiles.count > 1 else { return }
        let currentIndex = tabView.indexOfTabViewItem(tabView.selectedTabViewItem!)
        let profile = appConfig.profiles[currentIndex]

        let alert = NSAlert()
        alert.messageText = "Delete Profile \(currentIndex + 1)?"
        alert.informativeText = "\(profile.color.emoji) This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        appConfig.deleteProfile(at: currentIndex)
        rebuildTabs()
        tabView.selectTabViewItem(at: appConfig.safeIndex)
    }

    @objc private func moveProfileLeft() {
        let index = tabView.indexOfTabViewItem(tabView.selectedTabViewItem!)
        guard index > 0 else { return }
        appConfig.moveProfile(from: index, to: index - 1)
        rebuildTabs()
        tabView.selectTabViewItem(at: index - 1)
    }

    @objc private func moveProfileRight() {
        let index = tabView.indexOfTabViewItem(tabView.selectedTabViewItem!)
        guard index < appConfig.profiles.count - 1 else { return }
        appConfig.moveProfile(from: index, to: index + 1)
        rebuildTabs()
        tabView.selectTabViewItem(at: index + 1)
    }

    private func rebuildTabs() {
        while tabView.numberOfTabViewItems > 0 {
            tabView.removeTabViewItem(tabView.tabViewItems[0])
        }
        for index in appConfig.profiles.indices {
            addTab(for: index)
        }
    }
}

