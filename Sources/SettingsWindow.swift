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

// MARK: - Settings Window Controller

final class SettingsWindowController: NSWindowController, NSTabViewDelegate {
    var appConfig: AppConfig
    var onSave: ((AppConfig) -> Void)?
    private var tabView: NSTabView!
    private var switchPopup: NSPopUpButton!
    private var builtTabs: Set<UUID> = []

    private lazy var sharedKeyMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(withTitle: "— Select key —", action: nil, keyEquivalent: "")
        for section in keySections {
            menu.addItem(.separator())
            let header = NSMenuItem(title: section.title, action: nil, keyEquivalent: "")
            header.isEnabled = false
            header.attributedTitle = NSAttributedString(string: section.title, attributes: [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
            menu.addItem(header)
            for key in section.keys {
                let item = NSMenuItem(title: key.name, action: nil, keyEquivalent: "")
                item.representedObject = key.keyCode as NSNumber
                menu.addItem(item)
            }
        }
        return menu
    }()

    init(appConfig: AppConfig) {
        self.appConfig = appConfig
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 570, height: 680),
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

        let width: CGFloat = 570
        let totalHeight: CGFloat = 680
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: totalHeight))
        var y: CGFloat = 16

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(saveConfig))
        saveBtn.frame = NSRect(x: width - 100, y: y, width: 80, height: 32)
        saveBtn.keyEquivalent = "\r"
        contentView.addSubview(saveBtn)
        y += 44

        addSeparator(to: contentView, at: y, width: width)
        y += 16

        let switchLabel = NSTextField(labelWithString: "Switch profiles:")
        switchLabel.frame = NSRect(x: 20, y: y + 2, width: 110, height: 20)
        switchLabel.alignment = .right
        switchLabel.font = NSFont.systemFont(ofSize: 13)
        contentView.addSubview(switchLabel)

        switchPopup = NSPopUpButton(frame: NSRect(x: 140, y: y, width: 160, height: 26), pullsDown: false)
        for btn in SwitchButton.allCases { switchPopup.addItem(withTitle: btn.rawValue) }
        switchPopup.selectItem(at: SwitchButton.allCases.firstIndex(of: appConfig.switchButton) ?? 0)
        switchPopup.target = self
        switchPopup.action = #selector(switchButtonChanged)
        contentView.addSubview(switchPopup)
        y += 38

        addSeparator(to: contentView, at: y, width: width)
        y += 8

        let tabHeight = totalHeight - y - 10
        tabView = NSTabView(frame: NSRect(x: 10, y: y, width: width - 20, height: tabHeight))
        tabView.delegate = self
        contentView.addSubview(tabView)

        for index in appConfig.profiles.indices { addTab(for: index) }
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

    private func selectDropdownItem(_ dropdown: NSPopUpButton, for keyCode: UInt16) {
        guard let menu = dropdown.menu else { return }
        for (i, item) in menu.items.enumerated() {
            if (item.representedObject as? NSNumber)?.uint16Value == keyCode {
                dropdown.selectItem(at: i)
                return
            }
        }
        dropdown.selectItem(at: 0)
    }

    // MARK: - Tabs

    private func addTab(for profileIndex: Int) {
        let profile = appConfig.profiles[profileIndex]
        let item = NSTabViewItem(identifier: profile.id)
        item.label = "\(profile.color.emoji) Profile \(profileIndex + 1)"
        item.view = NSView()
        tabView.addTabViewItem(item)
    }

    private func ensureTabBuilt(_ item: NSTabViewItem) {
        guard let profileId = item.identifier as? UUID, !builtTabs.contains(profileId) else { return }
        builtTabs.insert(profileId)

        let contentView = buildMappingView(for: profileId)

        // Wrap in scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = contentView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false

        // Scroll to top (highest y in flipped=false coordinates)
        if let docView = scrollView.documentView {
            docView.scroll(NSPoint(x: 0, y: docView.bounds.height))
        }

        item.view = scrollView
    }

    func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        if let item = tabViewItem { ensureTabBuilt(item) }
    }

    // MARK: - Mapping View

    private func buildMappingView(for profileId: UUID) -> NSView {
        let width: CGFloat = 530
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

        // Mapping rows
        let profileIdx = appConfig.profiles.firstIndex(where: { $0.id == profileId })

        for button in ControllerButton.allCases.reversed() {
            let action = profileIdx.flatMap { appConfig.profiles[$0].action(for: button) }

            if case .macro(let steps) = action {
                // Macro: steps first (bottom), then label+controls on top
                y = buildMacroSteps(in: view, at: y, profileId: profileId, button: button, steps: steps, width: width)
                y = buildMacroControls(in: view, at: y, profileId: profileId, button: button, steps: steps, width: width)
            } else {
                // Single key: label + controls on same line
                let label = NSTextField(labelWithString: button.rawValue)
                label.frame = NSRect(x: 4, y: y + 3, width: 55, height: 18)
                label.alignment = .right
                label.font = NSFont.systemFont(ofSize: 12)
                view.addSubview(label)
                y = buildSingleKeyRow(in: view, at: y, profileId: profileId, button: button, action: action, width: width)
            }
        }

        // Hint
        y += 4
        let hint = NSTextField(labelWithString: "Record key or select from dropdown. [M] = macro mode, [K] = key mode.")
        hint.frame = NSRect(x: 10, y: y, width: width - 20, height: 16)
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        view.addSubview(hint)
        y += 24

        view.frame = NSRect(x: 0, y: 0, width: width, height: y)
        return view
    }

    // MARK: - Single Key Row

    private func buildSingleKeyRow(in view: NSView, at y: CGFloat, profileId: UUID, button: ControllerButton, action: ButtonAction?, width: CGFloat) -> CGFloat {
        let keyCode: UInt16? = {
            if case .singleKey(let kc) = action { return kc }
            return nil
        }()

        let captureBtn = KeyCaptureButton(frame: NSRect(x: 65, y: y, width: 80, height: 26))
        captureBtn.keyCode = keyCode
        captureBtn.updateTitle()
        view.addSubview(captureBtn)

        let dropdown = NSPopUpButton(frame: NSRect(x: 150, y: y, width: 190, height: 26), pullsDown: false)
        dropdown.menu = sharedKeyMenu.copy() as? NSMenu
        if let kc = keyCode { selectDropdownItem(dropdown, for: kc) }
        view.addSubview(dropdown)

        let clearBtn = NSButton(title: "✕", target: nil, action: nil)
        clearBtn.bezelStyle = .rounded
        clearBtn.frame = NSRect(x: 346, y: y, width: 26, height: 26)
        view.addSubview(clearBtn)

        // Macro toggle
        let macroBtn = NSButton(title: "M", target: nil, action: nil)
        macroBtn.bezelStyle = .rounded
        macroBtn.toolTip = "Switch to Macro mode"
        macroBtn.frame = NSRect(x: 378, y: y, width: 26, height: 26)
        view.addSubview(macroBtn)

        // Wire up capture → dropdown sync + config
        captureBtn.onCapture = { [weak self, weak dropdown] keyCode in
            guard let self, let idx = self.profileIndex(for: profileId) else { return }
            self.appConfig.profiles[idx].setAction(.singleKey(keyCode), for: button)
            if let dropdown { self.selectDropdownItem(dropdown, for: keyCode) }
        }

        // Wire up dropdown → capture sync + config
        let dropHandler = ActionHandler(profileId: profileId, button: button, controller: self)
        dropHandler.onDropdown = { [weak captureBtn] keyCode in
            captureBtn?.keyCode = keyCode
            captureBtn?.updateTitle()
        }
        dropdown.target = dropHandler
        dropdown.action = #selector(ActionHandler.dropdownChanged(_:))
        objc_setAssociatedObject(dropdown, "handler", dropHandler, .OBJC_ASSOCIATION_RETAIN)

        // Clear
        let clearHandler = ActionHandler(profileId: profileId, button: button, controller: self)
        clearHandler.onClear = { [weak captureBtn, weak dropdown] in
            captureBtn?.keyCode = nil
            captureBtn?.updateTitle()
            dropdown?.selectItem(at: 0)
        }
        clearBtn.target = clearHandler
        clearBtn.action = #selector(ActionHandler.clear)
        objc_setAssociatedObject(clearBtn, "handler", clearHandler, .OBJC_ASSOCIATION_RETAIN)

        // Macro toggle
        let macroToggle = ActionHandler(profileId: profileId, button: button, controller: self)
        macroToggle.onToggleMacro = { [weak self] in
            guard let self, let idx = self.profileIndex(for: profileId) else { return }
            self.appConfig.profiles[idx].setAction(.macro([]), for: button)
            self.rebuildCurrentTab()
        }
        macroBtn.target = macroToggle
        macroBtn.action = #selector(ActionHandler.toggleMacro)
        objc_setAssociatedObject(macroBtn, "handler", macroToggle, .OBJC_ASSOCIATION_RETAIN)

        return y + 32
    }

    // MARK: - Macro Row

    /// Render macro steps at bottom (low y), returns y after last step
    private func buildMacroSteps(in view: NSView, at startY: CGFloat, profileId: UUID, button: ControllerButton, steps: [MacroStep], width: CGFloat) -> CGFloat {
        let indent: CGFloat = 65
        var y = startY

        // Steps in forward order — step 0 gets lowest y (bottom), reads correctly top-to-bottom
        for (stepIdx, step) in steps.enumerated().reversed() {
            y = buildStepRow(in: view, at: y, indent: indent, profileId: profileId, button: button, stepIndex: stepIdx, step: step, width: width)
        }
        return y
    }

    /// Render macro label + controls at top (high y)
    private func buildMacroControls(in view: NSView, at y: CGFloat, profileId: UUID, button: ControllerButton, steps: [MacroStep], width: CGFloat) -> CGFloat {
        let indent: CGFloat = 65

        // Label
        let label = NSTextField(labelWithString: button.rawValue)
        label.frame = NSRect(x: 4, y: y + 3, width: 55, height: 18)
        label.alignment = .right
        label.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(label)

        // [K] button
        let keyBtn = NSButton(title: "K", target: nil, action: nil)
        keyBtn.bezelStyle = .rounded
        keyBtn.toolTip = "Switch to Key mode"
        keyBtn.frame = NSRect(x: indent, y: y, width: 26, height: 24)
        view.addSubview(keyBtn)

        let keyToggle = ActionHandler(profileId: profileId, button: button, controller: self)
        keyToggle.onToggleMacro = { [weak self] in
            guard let self, let idx = self.profileIndex(for: profileId) else { return }
            self.appConfig.profiles[idx].setAction(nil, for: button)
            self.rebuildCurrentTab()
        }
        keyBtn.target = keyToggle
        keyBtn.action = #selector(ActionHandler.toggleMacro)
        objc_setAssociatedObject(keyBtn, "handler", keyToggle, .OBJC_ASSOCIATION_RETAIN)

        // [+ Step] button
        let addBtn = NSButton(title: "+ Step", target: nil, action: nil)
        addBtn.bezelStyle = .rounded
        addBtn.frame = NSRect(x: indent + 32, y: y, width: 60, height: 24)
        view.addSubview(addBtn)

        let addHandler = ActionHandler(profileId: profileId, button: button, controller: self)
        addHandler.onAddStep = { [weak self] in
            guard let self, let idx = self.profileIndex(for: profileId) else { return }
            if case .macro(var existingSteps) = self.appConfig.profiles[idx].action(for: button) {
                existingSteps.append(.keyCombo(nil, modifiers: []))
                self.appConfig.profiles[idx].setAction(.macro(existingSteps), for: button)
                self.rebuildCurrentTab()
            }
        }
        addBtn.target = addHandler
        addBtn.action = #selector(ActionHandler.addStep)
        objc_setAssociatedObject(addBtn, "handler", addHandler, .OBJC_ASSOCIATION_RETAIN)

        if steps.isEmpty {
            let empty = NSTextField(labelWithString: "(no steps)")
            empty.frame = NSRect(x: indent + 98, y: y + 3, width: 100, height: 18)
            empty.font = NSFont.systemFont(ofSize: 11)
            empty.textColor = .secondaryLabelColor
            view.addSubview(empty)
        }

        return y + 30
    }

    private func buildStepRow(in view: NSView, at y: CGFloat, indent: CGFloat, profileId: UUID, button: ControllerButton, stepIndex: Int, step: MacroStep, width: CGFloat) -> CGFloat {
        var x = indent

        // Step number
        let numLabel = NSTextField(labelWithString: "\(stepIndex + 1).")
        numLabel.frame = NSRect(x: x, y: y + 2, width: 18, height: 18)
        numLabel.font = NSFont.systemFont(ofSize: 11)
        numLabel.textColor = .secondaryLabelColor
        view.addSubview(numLabel)
        x += 20

        // Step type dropdown
        let typePopup = NSPopUpButton(frame: NSRect(x: x, y: y, width: 90, height: 22), pullsDown: false)
        typePopup.font = NSFont.systemFont(ofSize: 11)
        typePopup.addItem(withTitle: "Key Combo")
        typePopup.addItem(withTitle: "Type Text")
        typePopup.selectItem(at: step.type == .typeText ? 1 : 0)
        view.addSubview(typePopup)

        let typeHandler = StepHandler(profileId: profileId, button: button, stepIndex: stepIndex, controller: self)
        typeHandler.onTypeChange = { [weak self] newType in
            guard let self, let idx = self.profileIndex(for: profileId),
                  case .macro(var steps) = self.appConfig.profiles[idx].action(for: button),
                  stepIndex < steps.count else { return }
            steps[stepIndex] = newType == 0 ? .keyCombo(nil, modifiers: []) : .typeText("")
            self.appConfig.profiles[idx].setAction(.macro(steps), for: button)
            self.rebuildCurrentTab()
        }
        typePopup.target = typeHandler
        typePopup.action = #selector(StepHandler.typeChanged(_:))
        objc_setAssociatedObject(typePopup, "handler", typeHandler, .OBJC_ASSOCIATION_RETAIN)
        x += 95

        if step.type == .keyCombo {
            // Key record button
            let captureBtn = KeyCaptureButton(frame: NSRect(x: x, y: y, width: 70, height: 22))
            captureBtn.keyCode = step.keyCode
            captureBtn.updateTitle()
            captureBtn.font = NSFont.systemFont(ofSize: 11)
            view.addSubview(captureBtn)
            x += 75

            captureBtn.onCapture = { [weak self] keyCode in
                guard let self, let idx = self.profileIndex(for: profileId),
                      case .macro(var steps) = self.appConfig.profiles[idx].action(for: button),
                      stepIndex < steps.count else { return }
                steps[stepIndex] = .keyCombo(keyCode, modifiers: steps[stepIndex].modifiers)
                self.appConfig.profiles[idx].setAction(.macro(steps), for: button)
            }

            // Modifier checkboxes inline
            for (symbol, mod) in [("⌘", "cmd"), ("⇧", "shift"), ("⌥", "opt"), ("⌃", "ctrl")] {
                let cb = NSButton(checkboxWithTitle: symbol, target: nil, action: nil)
                cb.frame = NSRect(x: x, y: y, width: 34, height: 22)
                cb.state = step.modifiers.contains(mod) ? .on : .off
                view.addSubview(cb)

                let modHandler = StepHandler(profileId: profileId, button: button, stepIndex: stepIndex, controller: self)
                modHandler.modifierName = mod
                cb.target = modHandler
                cb.action = #selector(StepHandler.modifierToggled(_:))
                objc_setAssociatedObject(cb, "handler", modHandler, .OBJC_ASSOCIATION_RETAIN)
                x += 36
            }
        } else {
            // Text field
            let textField = NSTextField(frame: NSRect(x: x, y: y, width: width - x - 40, height: 22))
            textField.stringValue = step.text ?? ""
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.placeholderString = "Type text here..."
            view.addSubview(textField)

            let textHandler = StepHandler(profileId: profileId, button: button, stepIndex: stepIndex, controller: self)
            textField.delegate = textHandler
            objc_setAssociatedObject(textField, "handler", textHandler, .OBJC_ASSOCIATION_RETAIN)
        }

        // Delete step
        let delBtn = NSButton(title: "✕", target: nil, action: nil)
        delBtn.bezelStyle = .rounded
        delBtn.frame = NSRect(x: width - 35, y: y, width: 24, height: 22)
        view.addSubview(delBtn)

        let delHandler = StepHandler(profileId: profileId, button: button, stepIndex: stepIndex, controller: self)
        delHandler.onDelete = { [weak self] in
            guard let self, let idx = self.profileIndex(for: profileId),
                  case .macro(var steps) = self.appConfig.profiles[idx].action(for: button),
                  stepIndex < steps.count else { return }
            steps.remove(at: stepIndex)
            self.appConfig.profiles[idx].setAction(.macro(steps), for: button)
            self.rebuildCurrentTab()
        }
        delBtn.target = delHandler
        delBtn.action = #selector(StepHandler.deleteStep)
        objc_setAssociatedObject(delBtn, "handler", delHandler, .OBJC_ASSOCIATION_RETAIN)

        return y + 26
    }

    // MARK: - Helpers

    fileprivate func profileIndex(for id: UUID) -> Int? {
        appConfig.profiles.firstIndex(where: { $0.id == id })
    }

    private func rebuildCurrentTab() {
        guard let item = tabView.selectedTabViewItem, let id = item.identifier as? UUID else { return }
        builtTabs.remove(id)
        ensureTabBuilt(item)
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
        builtTabs.removeAll()
        for index in appConfig.profiles.indices { addTab(for: index) }
    }
}

// MARK: - Action Handler (single key row)

private final class ActionHandler: NSObject {
    let profileId: UUID
    let button: ControllerButton
    weak var controller: SettingsWindowController?
    var onDropdown: ((UInt16) -> Void)?
    var onClear: (() -> Void)?
    var onToggleMacro: (() -> Void)?
    var onAddStep: (() -> Void)?

    init(profileId: UUID, button: ControllerButton, controller: SettingsWindowController) {
        self.profileId = profileId
        self.button = button
        self.controller = controller
    }

    @objc func dropdownChanged(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem,
              let keyCode = (item.representedObject as? NSNumber)?.uint16Value,
              let controller, let idx = controller.profileIndex(for: profileId) else { return }
        controller.appConfig.profiles[idx].setAction(.singleKey(keyCode), for: button)
        onDropdown?(keyCode)
    }

    @objc func clear() {
        guard let controller, let idx = controller.profileIndex(for: profileId) else { return }
        controller.appConfig.profiles[idx].setAction(nil, for: button)
        onClear?()
    }

    @objc func toggleMacro() { onToggleMacro?() }
    @objc func addStep() { onAddStep?() }
}

// MARK: - Step Handler (macro step row)

private final class StepHandler: NSObject, NSTextFieldDelegate {
    let profileId: UUID
    let button: ControllerButton
    let stepIndex: Int
    weak var controller: SettingsWindowController?
    var onTypeChange: ((Int) -> Void)?
    var onDelete: (() -> Void)?
    var modifierName: String?

    init(profileId: UUID, button: ControllerButton, stepIndex: Int, controller: SettingsWindowController) {
        self.profileId = profileId
        self.button = button
        self.stepIndex = stepIndex
        self.controller = controller
    }

    @objc func typeChanged(_ sender: NSPopUpButton) {
        onTypeChange?(sender.indexOfSelectedItem)
    }

    @objc func deleteStep() { onDelete?() }

    @objc func modifierToggled(_ sender: NSButton) {
        guard let mod = modifierName, let controller,
              let idx = controller.profileIndex(for: profileId),
              case .macro(var steps) = controller.appConfig.profiles[idx].action(for: button),
              stepIndex < steps.count else { return }
        var mods = steps[stepIndex].modifiers
        if sender.state == .on { if !mods.contains(mod) { mods.append(mod) } } else { mods.removeAll { $0 == mod } }
        steps[stepIndex] = .keyCombo(steps[stepIndex].keyCode ?? 0, modifiers: mods)
        controller.appConfig.profiles[idx].setAction(.macro(steps), for: button)
    }

    // NSTextFieldDelegate — save text on edit
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, let controller,
              let idx = controller.profileIndex(for: profileId),
              case .macro(var steps) = controller.appConfig.profiles[idx].action(for: button),
              stepIndex < steps.count else { return }
        steps[stepIndex] = .typeText(textField.stringValue)
        controller.appConfig.profiles[idx].setAction(.macro(steps), for: button)
    }
}
