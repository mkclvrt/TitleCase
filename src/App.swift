import AppKit
import Carbon.HIToolbox
import ServiceManagement

// Entry point. Using @main avoids needing a file literally named main.swift,
// so the test harness can keep its own main.swift.
@main
struct TitleCaseApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu-bar only: no Dock icon, no main window.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    // UserDefaults keys.
    private let autoPasteKey = "autoPasteInPlace"
    private let styleKey = "titleStyle"            // "chicago" | "ap"
    private let hotKeyCodeKey = "hotKeyCode"
    private let hotKeyModsKey = "hotKeyMods"        // Carbon modifier mask
    private let hotKeyDisplayKey = "hotKeyDisplay"

    // Menu items we update at runtime.
    private var chicagoItem: NSMenuItem!
    private var apItem: NSMenuItem!
    private var hotKeyItem: NSMenuItem!

    // Hotkey recorder state.
    private var recorderWindow: NSWindow?
    private var recorderMonitor: Any?

    // MARK: - Settings (with sensible defaults)

    private var autoPaste: Bool {
        get { UserDefaults.standard.bool(forKey: autoPasteKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoPasteKey) }
    }

    private var style: TitleCase.Style {
        get { UserDefaults.standard.string(forKey: styleKey) == "ap" ? .ap : .chicago }
        set { UserDefaults.standard.set(newValue == .ap ? "ap" : "chicago", forKey: styleKey) }
    }

    private var hotKeyCode: UInt32 {
        UInt32(UserDefaults.standard.object(forKey: hotKeyCodeKey) as? Int ?? kVK_ANSI_T)
    }
    private var hotKeyMods: UInt32 {
        UInt32(UserDefaults.standard.object(forKey: hotKeyModsKey) as? Int ?? Int(controlKey | optionKey))
    }
    private var hotKeyDisplay: String {
        UserDefaults.standard.string(forKey: hotKeyDisplayKey) ?? "⌃⌥T"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        registerHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotKey()
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(symbol: "textformat", accessibility: "Title Case")

        let menu = NSMenu()

        let convert = NSMenuItem(
            title: "Convert Clipboard to Title Case",
            action: #selector(convertClipboard), keyEquivalent: "")
        convert.target = self
        menu.addItem(convert)

        menu.addItem(.separator())

        // Style submenu (radio-style: Chicago or AP).
        let styleParent = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        let styleMenu = NSMenu()
        chicagoItem = NSMenuItem(title: "Chicago", action: #selector(chooseChicago), keyEquivalent: "")
        chicagoItem.target = self
        chicagoItem.toolTip = "Lowercases prepositions of any length (about, toward, between…)."
        apItem = NSMenuItem(title: "AP", action: #selector(chooseAP), keyEquivalent: "")
        apItem.target = self
        apItem.toolTip = "Capitalizes prepositions of four or more letters (About, Toward, Between…)."
        styleMenu.addItem(chicagoItem)
        styleMenu.addItem(apItem)
        styleParent.submenu = styleMenu
        menu.addItem(styleParent)
        refreshStyleChecks()

        menu.addItem(.separator())

        // Hotkey — now clickable to re-record.
        hotKeyItem = NSMenuItem(
            title: "Change Hotkey…  (\(hotKeyDisplay))",
            action: #selector(changeHotKey), keyEquivalent: "")
        hotKeyItem.target = self
        menu.addItem(hotKeyItem)

        let autoPasteItem = NSMenuItem(
            title: "Replace selection in place",
            action: #selector(toggleAutoPaste), keyEquivalent: "")
        autoPasteItem.target = self
        autoPasteItem.state = autoPaste ? .on : .off
        autoPasteItem.toolTip = "When on, the hotkey copies the selected text, "
            + "title-cases it, and pastes it back. Requires Accessibility permission."
        menu.addItem(autoPasteItem)

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func refreshStyleChecks() {
        chicagoItem.state = (style == .chicago) ? .on : .off
        apItem.state = (style == .ap) ? .on : .off
    }

    private func setIcon(symbol: String, accessibility: String) {
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: accessibility)
            image?.isTemplate = true
            button.image = image
        }
    }

    // Briefly flash a checkmark (or x-mark) to confirm an action, then restore.
    private func flash(success: Bool) {
        setIcon(symbol: success ? "checkmark" : "xmark", accessibility: success ? "Done" : "Nothing to convert")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.setIcon(symbol: "textformat", accessibility: "Title Case")
        }
    }

    // MARK: - Actions

    @objc private func convertClipboard() {
        runConversion(replaceInPlace: false)
    }

    @objc private func chooseChicago() {
        style = .chicago
        refreshStyleChecks()
    }

    @objc private func chooseAP() {
        style = .ap
        refreshStyleChecks()
    }

    @objc private func toggleAutoPaste(_ sender: NSMenuItem) {
        if !autoPaste {
            // Turning it on requires Accessibility permission.
            if !ensureAccessibilityPermission() { return }
            autoPaste = true
            sender.state = .on
        } else {
            autoPaste = false
            sender.state = .off
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    sender.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    sender.state = .on
                }
            } catch {
                NSSound.beep()
            }
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    // MARK: - Core conversion

    fileprivate func handleHotKey() {
        runConversion(replaceInPlace: autoPaste)
    }

    private func runConversion(replaceInPlace: Bool) {
        let pasteboard = NSPasteboard.general

        if replaceInPlace {
            sendCommandKey(CGKeyCode(kVK_ANSI_C))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self = self else { return }
                let ok = self.transformPasteboard(pasteboard)
                if ok { self.sendCommandKey(CGKeyCode(kVK_ANSI_V)) }
                self.flash(success: ok)
            }
        } else {
            flash(success: transformPasteboard(pasteboard))
        }
    }

    @discardableResult
    private func transformPasteboard(_ pasteboard: NSPasteboard) -> Bool {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            return false
        }
        let converted = TitleCase.convert(text, style: style)
        pasteboard.clearContents()
        pasteboard.setString(converted, forType: .string)
        return true
    }

    // MARK: - Synthetic keystrokes (need Accessibility permission)

    private func sendCommandKey(_ key: CGKeyCode) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    @discardableResult
    private func ensureAccessibilityPermission() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Hotkey recorder

    @objc private func changeHotKey() {
        if recorderWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 130),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Set Global Hotkey"
            w.isReleasedWhenClosed = false
            w.center()
            let label = NSTextField(wrappingLabelWithString:
                "Press the new shortcut.\n\nMust include ⌘, ⌃, or ⌥.\nPress Esc to cancel.")
            label.alignment = .center
            label.frame = NSRect(x: 20, y: 15, width: 340, height: 100)
            label.isEditable = false
            label.isBezeled = false
            label.drawsBackground = false
            w.contentView?.addSubview(label)
            recorderWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        recorderWindow?.makeKeyAndOrderFront(nil)
        if recorderMonitor == nil {
            recorderMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleRecorderKey(event)
                return nil  // swallow the key so it isn't typed anywhere
            }
        }
    }

    private func handleRecorderKey(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            closeRecorder()
            return
        }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard mods.contains(.command) || mods.contains(.control) || mods.contains(.option) else {
            NSSound.beep()  // require at least one of ⌘ ⌃ ⌥
            return
        }

        var carbon: UInt32 = 0
        if mods.contains(.command) { carbon |= UInt32(cmdKey) }
        if mods.contains(.option)  { carbon |= UInt32(optionKey) }
        if mods.contains(.control) { carbon |= UInt32(controlKey) }
        if mods.contains(.shift)   { carbon |= UInt32(shiftKey) }

        let display = displayString(mods: mods, event: event)

        UserDefaults.standard.set(Int(event.keyCode), forKey: hotKeyCodeKey)
        UserDefaults.standard.set(Int(carbon), forKey: hotKeyModsKey)
        UserDefaults.standard.set(display, forKey: hotKeyDisplayKey)

        unregisterHotKey()
        registerHotKey()
        hotKeyItem.title = "Change Hotkey…  (\(display))"
        closeRecorder()
    }

    private func displayString(mods: NSEvent.ModifierFlags, event: NSEvent) -> String {
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option)  { s += "⌥" }
        if mods.contains(.shift)   { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        let key = (event.charactersIgnoringModifiers ?? "").uppercased()
        s += key.isEmpty ? "?" : key
        return s
    }

    private func closeRecorder() {
        if let m = recorderMonitor {
            NSEvent.removeMonitor(m)
            recorderMonitor = nil
        }
        recorderWindow?.orderOut(nil)
    }

    // MARK: - Global hotkey (Carbon)

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { (_, _, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { delegate.handleHotKey() }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x54_43_48_4B /* "TCHK" */), id: 1)
        RegisterEventHotKey(hotKeyCode, hotKeyMods, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}
