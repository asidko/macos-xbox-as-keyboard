import Foundation
import Carbon.HIToolbox
import os

private let log = Logger(subsystem: "com.xboxaskeyboard.dpad", category: "config")

// MARK: - Controller Buttons

enum ControllerButton: String, CaseIterable, Codable {
    case dpadUp = "D-pad Up"
    case dpadDown = "D-pad Down"
    case dpadLeft = "D-pad Left"
    case dpadRight = "D-pad Right"
    case a = "A"
    case b = "B"
    case x = "X"
    case y = "Y"
    case leftBumper = "LB"
    case rightBumper = "RB"
    case leftTrigger = "LT"
    case rightTrigger = "RT"
}

// MARK: - Key Code Display Names

enum KeyCodeNames {
    static func name(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Space: return "Space"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        case kVK_ForwardDelete: return "Fwd Del"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        default: return "Key \(keyCode)"
        }
    }

    /// Arrow/function keys need special CGEvent flags
    static func eventFlags(for keyCode: UInt16) -> CGEventFlags {
        let fnKeys: Set<UInt16> = [
            UInt16(kVK_UpArrow), UInt16(kVK_DownArrow), UInt16(kVK_LeftArrow), UInt16(kVK_RightArrow),
            UInt16(kVK_Home), UInt16(kVK_End), UInt16(kVK_PageUp), UInt16(kVK_PageDown),
            UInt16(kVK_ForwardDelete),
            UInt16(kVK_F1), UInt16(kVK_F2), UInt16(kVK_F3), UInt16(kVK_F4),
            UInt16(kVK_F5), UInt16(kVK_F6), UInt16(kVK_F7), UInt16(kVK_F8),
            UInt16(kVK_F9), UInt16(kVK_F10), UInt16(kVK_F11), UInt16(kVK_F12),
        ]
        let numPadKeys: Set<UInt16> = [
            UInt16(kVK_UpArrow), UInt16(kVK_DownArrow), UInt16(kVK_LeftArrow), UInt16(kVK_RightArrow),
        ]
        var flags: CGEventFlags = []
        if fnKeys.contains(keyCode) { flags.insert(.maskSecondaryFn) }
        if numPadKeys.contains(keyCode) { flags.insert(.maskNumericPad) }
        return flags
    }
}

// MARK: - Mapping Configuration

struct MappingConfig: Codable {
    var mappings: [String: UInt16]

    static let defaultMappings: [ControllerButton: UInt16] = [
        .dpadUp: UInt16(kVK_UpArrow),
        .dpadDown: UInt16(kVK_DownArrow),
        .dpadLeft: UInt16(kVK_LeftArrow),
        .dpadRight: UInt16(kVK_RightArrow),
        .a: UInt16(kVK_ANSI_A),
        .b: UInt16(kVK_ANSI_B),
        .x: UInt16(kVK_ANSI_X),
        .y: UInt16(kVK_ANSI_Y),
        .leftBumper: UInt16(kVK_PageUp),
        .rightBumper: UInt16(kVK_PageDown),
        .leftTrigger: UInt16(kVK_Home),
        .rightTrigger: UInt16(kVK_End),
    ]

    init() {
        mappings = [:]
        for (button, keyCode) in Self.defaultMappings {
            mappings[button.rawValue] = keyCode
        }
    }

    func keyCode(for button: ControllerButton) -> UInt16? {
        mappings[button.rawValue]
    }

    mutating func setKeyCode(_ keyCode: UInt16?, for button: ControllerButton) {
        if let keyCode {
            mappings[button.rawValue] = keyCode
        } else {
            mappings.removeValue(forKey: button.rawValue)
        }
    }
}

// MARK: - Config Persistence

enum ConfigStore {
    private static let configDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".xboxaskeyboard")
    private static let configFile = configDir.appendingPathComponent("config.json")

    static func load() -> MappingConfig {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            log.info("No config file, using defaults")
            return MappingConfig()
        }
        do {
            let data = try Data(contentsOf: configFile)
            let config = try JSONDecoder().decode(MappingConfig.self, from: data)
            log.info("Config loaded from \(configFile.path)")
            return config
        } catch {
            log.error("Failed to load config: \(error.localizedDescription)")
            return MappingConfig()
        }
    }

    static func save(_ config: MappingConfig) {
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configFile, options: .atomic)
            log.info("Config saved to \(configFile.path)")
        } catch {
            log.error("Failed to save config: \(error.localizedDescription)")
        }
    }
}
