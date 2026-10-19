import AppKit
import Carbon.HIToolbox
import Combine
import ServiceManagement

/// A global shortcut: virtual key code + Carbon modifier flags.
struct KeyCombo: Codable, Equatable {
    var keyCode: Int
    var modifiers: Int

    static let switcherDefault = KeyCombo(keyCode: kVK_Space, modifiers: controlKey | optionKey)
    static let deckDefault = KeyCombo(keyCode: kVK_ANSI_D, modifiers: controlKey | optionKey)

    init(keyCode: Int, modifiers: Int) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods = 0
        if flags.contains(.command) { mods |= cmdKey }
        if flags.contains(.option) { mods |= optionKey }
        if flags.contains(.control) { mods |= controlKey }
        if flags.contains(.shift) { mods |= shiftKey }
        let isFunctionKey = Self.functionKeys[Int(event.keyCode)] != nil
        // Plain letters would hijack typing everywhere; require a real modifier.
        guard isFunctionKey || mods & (cmdKey | optionKey | controlKey) != 0 else { return nil }
        self.init(keyCode: Int(event.keyCode), modifiers: mods)
    }

    var display: String {
        var s = ""
        if modifiers & controlKey != 0 { s += "⌃" }
        if modifiers & optionKey != 0 { s += "⌥" }
        if modifiers & shiftKey != 0 { s += "⇧" }
        if modifiers & cmdKey != 0 { s += "⌘" }
        return s + keyName
    }

    var keyName: String {
        if let name = Self.specialKeys[keyCode] ?? Self.functionKeys[keyCode] { return name }
        // Translate through the current keyboard layout so ⌥⌘Z shows as Z on AZERTY too.
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "?" }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var dead: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            UCKeyTranslate(raw.bindMemory(to: UCKeyboardLayout.self).baseAddress, UInt16(keyCode),
                           UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                           OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 4, &length, &chars)
        }
        guard status == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }

    /// A system shortcut (Spotlight, input sources, Mission Control…) using the same combo.
    var systemConflict: Bool {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr,
              let list = unmanaged?.takeRetainedValue() as? [[String: Any]] else { return false }
        return list.contains { entry in
            guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
                  let code = entry[kHISymbolicHotKeyCode as String] as? Int,
                  let mods = entry[kHISymbolicHotKeyModifiers as String] as? Int else { return false }
            return code == keyCode && mods & Self.carbonMask == modifiers & Self.carbonMask
        }
    }

    private static let carbonMask = cmdKey | optionKey | controlKey | shiftKey

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑",
        kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]
    private static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19",
    ]
}

/// User preferences, persisted in UserDefaults.
@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    /// nil = shortcut turned off.
    @Published var switcherHotKey: KeyCombo? { didSet { save(switcherHotKey, "switcherHotKey") } }
    @Published var deckHotKey: KeyCombo? { didSet { save(deckHotKey, "deckHotKey") } }
    @Published var disabledKinds: Set<String> { didSet { save(disabledKinds, "disabledKinds") } }
    @Published var customKinds: [AgentKind] { didSet { save(customKinds, "customKinds") } }
    @Published var deckColumns: Int { didSet { defaults.set(deckColumns, forKey: "deckColumns") } }
    /// First-run welcome dismissed.
    @Published var welcomed: Bool { didSet { defaults.set(welcomed, forKey: "welcomed") } }
    @Published var notifyWaiting: Bool { didSet { defaults.set(notifyWaiting, forKey: "notifyWaiting") } }
    @Published var notifyReady: Bool { didSet { defaults.set(notifyReady, forKey: "notifyReady") } }
    @Published var notificationSound: Bool { didSet { defaults.set(notificationSound, forKey: "notificationSound") } }
    /// Shortcuts that failed to register because another app owns them.
    @Published var hotKeyErrors: Set<String> = []
    /// True while a shortcut field is capturing keys; global hotkeys are unregistered meanwhile.
    @Published var isRecordingHotKey = false

    private init() {
        switcherHotKey = Self.load("switcherHotKey", default: KeyCombo.switcherDefault)
        deckHotKey = Self.load("deckHotKey", default: KeyCombo.deckDefault)
        disabledKinds = Self.load("disabledKinds", default: [])
        customKinds = Self.load("customKinds", default: [])
        let cols = UserDefaults.standard.integer(forKey: "deckColumns")
        deckColumns = cols == 0 ? 4 : cols
        let d = UserDefaults.standard
        d.register(defaults: ["notifyWaiting": true, "notifyReady": false, "notificationSound": true])
        welcomed = d.bool(forKey: "welcomed")
        notifyWaiting = d.bool(forKey: "notifyWaiting")
        notifyReady = d.bool(forKey: "notifyReady")
        notificationSound = d.bool(forKey: "notificationSound")
    }

    /// What the scanner should look for right now.
    var activeKinds: [AgentKind] {
        AgentKind.builtIns.filter { !disabledKinds.contains($0.id) } + customKinds
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                Log.write("launch at login: \(error)")
            }
            objectWillChange.send()
        }
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ key: String, default value: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(T.self, from: data) else { return value }
        return decoded
    }
}
