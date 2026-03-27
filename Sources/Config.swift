import AppKit
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

// MARK: - Profile Colors

enum ProfileColor: Int, CaseIterable, Codable {
    case blue = 0, green, red, orange, purple, yellow, cyan, pink

    var nsColor: NSColor {
        switch self {
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .purple: return .systemPurple
        case .yellow: return .systemYellow
        case .cyan: return .systemCyan
        case .pink: return .systemPink
        }
    }

    var emoji: String {
        switch self {
        case .blue: return "🔵"
        case .green: return "🟢"
        case .red: return "🔴"
        case .orange: return "🟠"
        case .purple: return "🟣"
        case .yellow: return "🟡"
        case .cyan: return "🩵"
        case .pink: return "🩷"
        }
    }

    static func forIndex(_ index: Int) -> ProfileColor {
        allCases[index % allCases.count]
    }
}

// MARK: - Key Code Registry (single source of truth)

struct KeyEntry {
    let name: String
    let keyCode: UInt16
}

struct KeySection {
    let title: String
    let keys: [KeyEntry]
}

let keySections: [KeySection] = [
    KeySection(title: "Arrows", keys: [
        KeyEntry(name: "↑ Up", keyCode: UInt16(kVK_UpArrow)),
        KeyEntry(name: "↓ Down", keyCode: UInt16(kVK_DownArrow)),
        KeyEntry(name: "← Left", keyCode: UInt16(kVK_LeftArrow)),
        KeyEntry(name: "→ Right", keyCode: UInt16(kVK_RightArrow)),
    ]),
    KeySection(title: "Navigation", keys: [
        KeyEntry(name: "Home", keyCode: UInt16(kVK_Home)),
        KeyEntry(name: "End", keyCode: UInt16(kVK_End)),
        KeyEntry(name: "Page Up", keyCode: UInt16(kVK_PageUp)),
        KeyEntry(name: "Page Down", keyCode: UInt16(kVK_PageDown)),
    ]),
    KeySection(title: "Special", keys: [
        KeyEntry(name: "Space", keyCode: UInt16(kVK_Space)),
        KeyEntry(name: "Return", keyCode: UInt16(kVK_Return)),
        KeyEntry(name: "Tab", keyCode: UInt16(kVK_Tab)),
        KeyEntry(name: "Escape", keyCode: UInt16(kVK_Escape)),
        KeyEntry(name: "Delete", keyCode: UInt16(kVK_Delete)),
        KeyEntry(name: "Fwd Delete", keyCode: UInt16(kVK_ForwardDelete)),
    ]),
    KeySection(title: "Letters", keys: [
        KeyEntry(name: "A", keyCode: UInt16(kVK_ANSI_A)),
        KeyEntry(name: "B", keyCode: UInt16(kVK_ANSI_B)),
        KeyEntry(name: "C", keyCode: UInt16(kVK_ANSI_C)),
        KeyEntry(name: "D", keyCode: UInt16(kVK_ANSI_D)),
        KeyEntry(name: "E", keyCode: UInt16(kVK_ANSI_E)),
        KeyEntry(name: "F", keyCode: UInt16(kVK_ANSI_F)),
        KeyEntry(name: "G", keyCode: UInt16(kVK_ANSI_G)),
        KeyEntry(name: "H", keyCode: UInt16(kVK_ANSI_H)),
        KeyEntry(name: "I", keyCode: UInt16(kVK_ANSI_I)),
        KeyEntry(name: "J", keyCode: UInt16(kVK_ANSI_J)),
        KeyEntry(name: "K", keyCode: UInt16(kVK_ANSI_K)),
        KeyEntry(name: "L", keyCode: UInt16(kVK_ANSI_L)),
        KeyEntry(name: "M", keyCode: UInt16(kVK_ANSI_M)),
        KeyEntry(name: "N", keyCode: UInt16(kVK_ANSI_N)),
        KeyEntry(name: "O", keyCode: UInt16(kVK_ANSI_O)),
        KeyEntry(name: "P", keyCode: UInt16(kVK_ANSI_P)),
        KeyEntry(name: "Q", keyCode: UInt16(kVK_ANSI_Q)),
        KeyEntry(name: "R", keyCode: UInt16(kVK_ANSI_R)),
        KeyEntry(name: "S", keyCode: UInt16(kVK_ANSI_S)),
        KeyEntry(name: "T", keyCode: UInt16(kVK_ANSI_T)),
        KeyEntry(name: "U", keyCode: UInt16(kVK_ANSI_U)),
        KeyEntry(name: "V", keyCode: UInt16(kVK_ANSI_V)),
        KeyEntry(name: "W", keyCode: UInt16(kVK_ANSI_W)),
        KeyEntry(name: "X", keyCode: UInt16(kVK_ANSI_X)),
        KeyEntry(name: "Y", keyCode: UInt16(kVK_ANSI_Y)),
        KeyEntry(name: "Z", keyCode: UInt16(kVK_ANSI_Z)),
    ]),
    KeySection(title: "Numbers", keys: [
        KeyEntry(name: "0", keyCode: UInt16(kVK_ANSI_0)),
        KeyEntry(name: "1", keyCode: UInt16(kVK_ANSI_1)),
        KeyEntry(name: "2", keyCode: UInt16(kVK_ANSI_2)),
        KeyEntry(name: "3", keyCode: UInt16(kVK_ANSI_3)),
        KeyEntry(name: "4", keyCode: UInt16(kVK_ANSI_4)),
        KeyEntry(name: "5", keyCode: UInt16(kVK_ANSI_5)),
        KeyEntry(name: "6", keyCode: UInt16(kVK_ANSI_6)),
        KeyEntry(name: "7", keyCode: UInt16(kVK_ANSI_7)),
        KeyEntry(name: "8", keyCode: UInt16(kVK_ANSI_8)),
        KeyEntry(name: "9", keyCode: UInt16(kVK_ANSI_9)),
    ]),
    KeySection(title: "Function Keys", keys: [
        KeyEntry(name: "F1", keyCode: UInt16(kVK_F1)),
        KeyEntry(name: "F2", keyCode: UInt16(kVK_F2)),
        KeyEntry(name: "F3", keyCode: UInt16(kVK_F3)),
        KeyEntry(name: "F4", keyCode: UInt16(kVK_F4)),
        KeyEntry(name: "F5", keyCode: UInt16(kVK_F5)),
        KeyEntry(name: "F6", keyCode: UInt16(kVK_F6)),
        KeyEntry(name: "F7", keyCode: UInt16(kVK_F7)),
        KeyEntry(name: "F8", keyCode: UInt16(kVK_F8)),
        KeyEntry(name: "F9", keyCode: UInt16(kVK_F9)),
        KeyEntry(name: "F10", keyCode: UInt16(kVK_F10)),
        KeyEntry(name: "F11", keyCode: UInt16(kVK_F11)),
        KeyEntry(name: "F12", keyCode: UInt16(kVK_F12)),
    ]),
    KeySection(title: "Punctuation", keys: [
        KeyEntry(name: "- Minus", keyCode: UInt16(kVK_ANSI_Minus)),
        KeyEntry(name: "= Equal", keyCode: UInt16(kVK_ANSI_Equal)),
        KeyEntry(name: "[ Left Bracket", keyCode: UInt16(kVK_ANSI_LeftBracket)),
        KeyEntry(name: "] Right Bracket", keyCode: UInt16(kVK_ANSI_RightBracket)),
        KeyEntry(name: "\\ Backslash", keyCode: UInt16(kVK_ANSI_Backslash)),
        KeyEntry(name: "; Semicolon", keyCode: UInt16(kVK_ANSI_Semicolon)),
        KeyEntry(name: "' Quote", keyCode: UInt16(kVK_ANSI_Quote)),
        KeyEntry(name: ", Comma", keyCode: UInt16(kVK_ANSI_Comma)),
        KeyEntry(name: ". Period", keyCode: UInt16(kVK_ANSI_Period)),
        KeyEntry(name: "/ Slash", keyCode: UInt16(kVK_ANSI_Slash)),
        KeyEntry(name: "` Grave", keyCode: UInt16(kVK_ANSI_Grave)),
    ]),
    KeySection(title: "Modifiers", keys: [
        KeyEntry(name: "⌘ Command", keyCode: UInt16(kVK_Command)),
        KeyEntry(name: "⇧ Shift", keyCode: UInt16(kVK_Shift)),
        KeyEntry(name: "⌥ Option", keyCode: UInt16(kVK_Option)),
        KeyEntry(name: "⌃ Control", keyCode: UInt16(kVK_Control)),
        KeyEntry(name: "⌘ Right Command", keyCode: UInt16(kVK_RightCommand)),
        KeyEntry(name: "⇧ Right Shift", keyCode: UInt16(kVK_RightShift)),
        KeyEntry(name: "⌥ Right Option", keyCode: UInt16(kVK_RightOption)),
        KeyEntry(name: "⌃ Right Control", keyCode: UInt16(kVK_RightControl)),
    ]),
]
let allKeys: [KeyEntry] = keySections.flatMap(\.keys)

private let keyCodeToName: [UInt16: String] = {
    var map: [UInt16: String] = [:]
    for entry in allKeys { map[entry.keyCode] = entry.name }
    return map
}()

// MARK: - Key Code Utilities

enum KeyCodeNames {
    static func name(for keyCode: UInt16) -> String {
        keyCodeToName[keyCode] ?? "Key \(keyCode)"
    }

    private static let fnKeys: Set<UInt16> = [
        UInt16(kVK_UpArrow), UInt16(kVK_DownArrow), UInt16(kVK_LeftArrow), UInt16(kVK_RightArrow),
        UInt16(kVK_Home), UInt16(kVK_End), UInt16(kVK_PageUp), UInt16(kVK_PageDown),
        UInt16(kVK_ForwardDelete),
        UInt16(kVK_F1), UInt16(kVK_F2), UInt16(kVK_F3), UInt16(kVK_F4),
        UInt16(kVK_F5), UInt16(kVK_F6), UInt16(kVK_F7), UInt16(kVK_F8),
        UInt16(kVK_F9), UInt16(kVK_F10), UInt16(kVK_F11), UInt16(kVK_F12),
    ]
    private static let numPadKeys: Set<UInt16> = [
        UInt16(kVK_UpArrow), UInt16(kVK_DownArrow), UInt16(kVK_LeftArrow), UInt16(kVK_RightArrow),
    ]

    static func eventFlags(for keyCode: UInt16) -> CGEventFlags {
        var flags: CGEventFlags = []
        if fnKeys.contains(keyCode) { flags.insert(.maskSecondaryFn) }
        if numPadKeys.contains(keyCode) { flags.insert(.maskNumericPad) }
        return flags
    }

    private static let modifierFlags: [UInt16: CGEventFlags] = [
        UInt16(kVK_Command): .maskCommand,
        UInt16(kVK_RightCommand): .maskCommand,
        UInt16(kVK_Shift): .maskShift,
        UInt16(kVK_RightShift): .maskShift,
        UInt16(kVK_Option): .maskAlternate,
        UInt16(kVK_RightOption): .maskAlternate,
        UInt16(kVK_Control): .maskControl,
        UInt16(kVK_RightControl): .maskControl,
    ]

    static func isModifier(_ keyCode: UInt16) -> Bool {
        modifierFlags[keyCode] != nil
    }

    static func modifierFlag(for keyCode: UInt16) -> CGEventFlags? {
        modifierFlags[keyCode]
    }
}

// MARK: - Profile

struct Profile: Codable, Identifiable {
    var id: UUID
    var colorIndex: Int
    var mappings: [String: UInt16]

    // Legacy field — ignored but kept for backward compat decoding
    var name: String?

    var color: ProfileColor { ProfileColor.forIndex(colorIndex) }

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

    init(colorIndex: Int) {
        self.id = UUID()
        self.colorIndex = colorIndex
        self.mappings = [:]
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

// MARK: - Profile Switch Button

enum SwitchButton: String, CaseIterable, Codable {
    case menu_ = "Menu"
    case view_ = "View"
    case home = "Xbox/Home"
}

// MARK: - App Configuration

struct AppConfig: Codable {
    var profiles: [Profile]
    var activeProfileIndex: Int
    var switchButton: SwitchButton

    var activeProfile: Profile {
        precondition(!profiles.isEmpty, "AppConfig must have at least one profile")
        return profiles[safeIndex]
    }

    var safeIndex: Int {
        guard !profiles.isEmpty else { return 0 }
        return min(max(activeProfileIndex, 0), profiles.count - 1)
    }

    init() {
        profiles = [Profile(colorIndex: 0)]
        activeProfileIndex = 0
        switchButton = .menu_
    }

    private func nextColorIndex() -> Int {
        let used = Set(profiles.map { $0.colorIndex % ProfileColor.allCases.count })
        for i in 0..<ProfileColor.allCases.count {
            if !used.contains(i) { return i }
        }
        // All 8 colors used — cycle based on total count
        return profiles.count % ProfileColor.allCases.count
    }

    mutating func addProfile() -> Int {
        let index = profiles.count
        profiles.append(Profile(colorIndex: nextColorIndex()))
        return index
    }

    mutating func duplicateProfile(at index: Int) -> Int {
        var copy = profiles[index]
        copy.id = UUID()
        copy.colorIndex = nextColorIndex()
        profiles.insert(copy, at: index + 1)
        if activeProfileIndex > index { activeProfileIndex += 1 }
        return index + 1
    }

    mutating func deleteProfile(at index: Int) {
        guard profiles.count > 1 else { return }
        profiles.remove(at: index)
        if activeProfileIndex >= profiles.count {
            activeProfileIndex = profiles.count - 1
        }
    }

    mutating func moveProfile(from: Int, to: Int) {
        let profile = profiles.remove(at: from)
        profiles.insert(profile, at: to)
        if activeProfileIndex == from {
            activeProfileIndex = to
        } else if from < activeProfileIndex && to >= activeProfileIndex {
            activeProfileIndex -= 1
        } else if from > activeProfileIndex && to <= activeProfileIndex {
            activeProfileIndex += 1
        }
    }

    mutating func cycleProfile() {
        activeProfileIndex = (safeIndex + 1) % profiles.count
    }
}

// MARK: - Config Persistence

enum ConfigStore {
    private static let configDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/xboxaskeyboard")
    private static let configFile = configDir.appendingPathComponent("config.json")

    static func load() -> AppConfig {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            log.info("No config file, using defaults")
            return AppConfig()
        }
        do {
            let data = try Data(contentsOf: configFile)
            if let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
                log.info("Config loaded (\(config.profiles.count) profiles)")
                return config
            }
            if let legacy = try? JSONDecoder().decode(LegacyMappingConfig.self, from: data) {
                log.info("Migrating legacy config to profile format")
                var config = AppConfig()
                config.profiles[0].mappings = legacy.mappings
                save(config)
                return config
            }
            log.error("Failed to decode config, using defaults")
            return AppConfig()
        } catch {
            log.error("Failed to load config: \(error.localizedDescription)")
            return AppConfig()
        }
    }

    static func save(_ config: AppConfig) {
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configFile, options: .atomic)
            log.info("Config saved (\(config.profiles.count) profiles)")
        } catch {
            log.error("Failed to save config: \(error.localizedDescription)")
        }
    }
}

private struct LegacyMappingConfig: Codable {
    var mappings: [String: UInt16]
}
