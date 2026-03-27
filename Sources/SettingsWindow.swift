import AppKit
import Carbon.HIToolbox

// MARK: - Key Capture Button

/// A button that captures the next keyboard press and reports its keyCode.
final class KeyCaptureButton: NSButton {
    var keyCode: UInt16?
    var onCapture: ((UInt16) -> Void)?
    var onClear: (() -> Void)?
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
        if let keyCode {
            title = KeyCodeNames.name(for: keyCode)
        } else {
            title = "Not Set"
        }
    }

    @objc private func startCapture() {
        isCapturing = true
        title = "Press a key..."

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isCapturing else { return event }
            self.stopCapture()

            if event.keyCode == UInt16(kVK_Escape) {
                self.updateTitle()
                return nil
            }
            if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
                self.keyCode = nil
                self.updateTitle()
                self.onClear?()
                return nil
            }

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

    deinit {
        stopCapture()
    }
}

// MARK: - Settings Window Controller

final class SettingsWindowController: NSWindowController {
    var config: MappingConfig
    var onSave: ((MappingConfig) -> Void)?
    private var captureButtons: [ControllerButton: KeyCaptureButton] = [:]

    init(config: MappingConfig) {
        self.config = config
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 0),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Button Mappings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let window else { return }

        let width: CGFloat = 380
        let contentView = NSView()
        var y: CGFloat = 20

        // Save / Reset buttons at the bottom
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(saveConfig))
        saveBtn.frame = NSRect(x: width - 100, y: y, width: 80, height: 32)
        saveBtn.keyEquivalent = "\r"
        contentView.addSubview(saveBtn)

        let resetBtn = NSButton(title: "Reset", target: self, action: #selector(resetDefaults))
        resetBtn.frame = NSRect(x: width - 190, y: y, width: 80, height: 32)
        contentView.addSubview(resetBtn)

        y += 48

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: 20, y: y, width: width - 40, height: 1)
        contentView.addSubview(sep)
        y += 16

        // Button rows: bottom to top
        let buttons = Array(ControllerButton.allCases.reversed())
        for button in buttons {
            let label = NSTextField(labelWithString: button.rawValue)
            label.frame = NSRect(x: 20, y: y + 2, width: 120, height: 20)
            label.alignment = .right
            label.font = NSFont.systemFont(ofSize: 13)
            contentView.addSubview(label)

            let captureBtn = KeyCaptureButton(frame: NSRect(x: 160, y: y, width: 160, height: 26))
            captureBtn.keyCode = config.keyCode(for: button)
            captureBtn.updateTitle()
            captureBtn.onCapture = { [weak self] keyCode in
                self?.config.setKeyCode(keyCode, for: button)
            }
            captureBtn.onClear = { [weak self] in
                self?.config.setKeyCode(nil, for: button)
            }
            contentView.addSubview(captureBtn)
            captureButtons[button] = captureBtn

            y += 34
        }

        // Hint text at the top
        y += 8
        let hint = NSTextField(wrappingLabelWithString: "Click a button, then press a key to assign.\nEsc to cancel, Delete to clear.")
        hint.frame = NSRect(x: 20, y: y, width: width - 40, height: 32)
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        contentView.addSubview(hint)
        y += 44

        contentView.frame = NSRect(x: 0, y: 0, width: width, height: y)
        window.setContentSize(NSSize(width: width, height: y))
        window.contentView = contentView
    }

    @objc private func saveConfig() {
        onSave?(config)
        window?.close()
    }

    @objc private func resetDefaults() {
        config = MappingConfig()
        for button in ControllerButton.allCases {
            captureButtons[button]?.keyCode = config.keyCode(for: button)
            captureButtons[button]?.updateTitle()
        }
    }
}
