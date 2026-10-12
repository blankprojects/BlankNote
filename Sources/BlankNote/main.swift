import AppKit
import SwiftUI
import BlankNoteCore

final class DesktopPanel: NSPanel {
    var store: NotebookStore?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    @objc func undo(_ sender: Any?) { store?.undo() }
    @objc func redo(_ sender: Any?) { store?.redo() }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    var panel: DesktopPanel!
    var statusItem: NSStatusItem!
    let store = NotebookStore(directory: ProcessInfo.processInfo.environment["BLANKNOTE_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) })
    let state = WindowState()
    var expandedHeight: CGFloat = 600
    var shortcut: GlobalShortcut?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "org.blanknote.BlankNote").first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        let mainMenu = NSMenu()
        let appMenu = NSMenu(title: "BlankNote")
        let quit = appMenu.addItem(withTitle: "退出 BlankNote", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        let appItem = NSMenuItem(title: "BlankNote", action: nil, keyEquivalent: "")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        let edit = NSMenu(title: "编辑")
        for (title, selector, key) in [("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        let undo = edit.insertItem(withTitle: "撤销", action: #selector(undoContext), keyEquivalent: "z", at: 0)
        undo.target = self
        let redo = edit.insertItem(withTitle: "重做", action: #selector(redoContext), keyEquivalent: "z", at: 1)
        redo.target = self
        redo.keyEquivalentModifierMask = [.command, .shift]
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        editItem.submenu = edit
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
        panel = DesktopPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 600), styleMask: [.titled, .fullSizeContentView, .resizable], backing: .buffered, defer: false)
        panel.title = "BlankNote"
        panel.store = store
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.toolbar = nil
        // Only the explicit title drag region may move the window. Otherwise
        // AppKit can claim a row's drag before SwiftUI starts reordering it.
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = NSColor(paper)
        panel.hasShadow = true
        panel.minSize = NSSize(width: 300, height: 360)
        panel.maxSize = NSSize(width: 640, height: 1200)
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: NotebookView(store: store, state: state))
        panel.appearance = state.appearance.nsAppearance
        panel.setFrameAutosaveName("BlankNoteWindow")
        if !panel.setFrameUsingName("BlankNoteWindow"), let screen = NSScreen.main {
            let area = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: area.maxX - 404, y: area.maxY - 625))
        }
        // A disconnected monitor must never leave the resident note out of reach.
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }), let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - panel.frame.width - 24, y: screen.visibleFrame.maxY - panel.frame.height - 24))
        }
        state.onPin = { [weak self] in self?.togglePin() }
        state.onCollapse = { [weak self] in self?.toggleCollapse() }
        applyPin()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "BlankNote")
        shortcut = GlobalShortcut { [weak self] in self?.toggleVisibility() }
        rebuildMenu()
        panel.orderFrontRegardless()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let show = menu.addItem(withTitle: "显示 / 隐藏 BlankNote", action: #selector(toggleVisibility), keyEquivalent: "n")
        show.target = self
        show.keyEquivalentModifierMask = [.control, .option]
        if shortcut?.registered != true {
            menu.addItem(withTitle: "全局 ⌃⌥N 已被占用，当前应用内仍可用", action: nil, keyEquivalent: "")
        }
        let pin = menu.addItem(withTitle: "始终置顶", action: #selector(togglePin), keyEquivalent: "")
        pin.target = self
        pin.state = state.pinned ? .on : .off
        let appearanceMenu = NSMenu(title: "外观")
        for choice in AppearanceChoice.allCases {
            let item = appearanceMenu.addItem(withTitle: choice.title, action: #selector(changeAppearance(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.rawValue
            item.state = choice == state.appearance ? .on : .off
        }
        let appearanceItem = menu.addItem(withTitle: "外观", action: nil, keyEquivalent: "")
        appearanceItem.submenu = appearanceMenu
        let login = menu.addItem(withTitle: "登录时自动启动", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        if LoginSettings.isAvailable, let enabled = try? LoginSettings.isEnabled() {
            login.state = enabled ? .on : .off
        } else {
            login.action = nil
            login.title = "登录自启（需安装正式版本）"
        }
        menu.addItem(.separator())
        let undo = menu.addItem(withTitle: store.undoTitle.map { "撤销\($0)" } ?? "撤销待办操作", action: #selector(undoTodo), keyEquivalent: "")
        undo.target = self
        let redo = menu.addItem(withTitle: store.redoTitle.map { "重做\($0)" } ?? "重做待办操作", action: #selector(redoTodo), keyEquivalent: "")
        redo.target = self
        menu.addItem(.separator())
        let folder = menu.addItem(withTitle: "打开数据文件夹", action: #selector(openDataFolder), keyEquivalent: "")
        folder.target = self
        let loginSettings = menu.addItem(withTitle: "系统登录设置…", action: #selector(openLoginSettings), keyEquivalent: "")
        loginSettings.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "退出 BlankNote", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
        NSApp.mainMenu?.item(at: 0)?.submenu = menu.copy() as? NSMenu
    }

    @objc func undoTodo() {
        NotificationCenter.default.post(name: .blankNoteCommitEditing, object: nil)
        store.undo()
    }
    @objc func redoTodo() { store.redo() }

    private var textUndoManager: UndoManager? { (panel?.firstResponder as? NSTextView)?.undoManager }

    @objc func undoContext() {
        if let manager = textUndoManager, manager.canUndo { manager.undo() }
        else { undoTodo() }
    }

    @objc func redoContext() {
        if let manager = textUndoManager, manager.canRedo { manager.redo() }
        else { redoTodo() }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(undoTodo) {
            menuItem.title = store.undoTitle.map { "撤销\($0)" } ?? "撤销待办操作"
            return store.undoTitle != nil
        }
        if menuItem.action == #selector(redoTodo) {
            menuItem.title = store.redoTitle.map { "重做\($0)" } ?? "重做待办操作"
            return store.redoTitle != nil
        }
        if menuItem.action == #selector(undoContext) {
            let text = textUndoManager?.canUndo == true
            menuItem.title = text ? "撤销输入" : store.undoTitle.map { "撤销\($0)" } ?? "撤销"
            return text || store.undoTitle != nil
        }
        if menuItem.action == #selector(redoContext) {
            let text = textUndoManager?.canRedo == true
            menuItem.title = text ? "重做输入" : store.redoTitle.map { "重做\($0)" } ?? "重做"
            return text || store.redoTitle != nil
        }
        return true
    }

    @objc func changeAppearance(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let choice = AppearanceChoice(rawValue: raw) else { return }
        state.appearance = choice
        UserDefaults.standard.set(raw, forKey: "appearance")
        panel.appearance = choice.nsAppearance
        rebuildMenu()
    }

    @objc func toggleLogin() {
        guard LoginSettings.isAvailable else { return }
        do {
            try LoginSettings.setEnabled(!LoginSettings.isEnabled())
            rebuildMenu()
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法更新登录自启"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }

    @objc func toggleVisibility() {
        if panel.isVisible && panel.isKeyWindow {
            NotificationCenter.default.post(name: .blankNoteCommitEditing, object: nil)
            panel.orderOut(nil)
        } else { showNote() }
    }

    @objc func showNote() {
        if state.collapsed { toggleCollapse() }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        state.focusRequest += 1
    }

    @objc func togglePin() {
        state.pinned.toggle()
        UserDefaults.standard.set(state.pinned, forKey: "pinned")
        applyPin()
        rebuildMenu()
    }

    private func applyPin() { panel.level = state.pinned ? .floating : .normal }

    func toggleCollapse() {
        var frame = panel.frame
        if state.collapsed {
            state.collapsed = false
            panel.minSize = NSSize(width: 300, height: 360)
            frame.origin.y -= expandedHeight - frame.height
            frame.size.height = expandedHeight
        } else {
            panel.saveFrame(usingName: "BlankNoteWindow")
            panel.setFrameAutosaveName("")
            expandedHeight = frame.height
            state.collapsed = true
            NotificationCenter.default.post(name: .blankNoteCommitEditing, object: nil)
            panel.minSize = NSSize(width: 300, height: 76)
            frame.origin.y += frame.height - 76
            frame.size.height = 76
        }
        panel.setFrame(frame, display: true, animate: false)
        if !state.collapsed { panel.setFrameAutosaveName("BlankNoteWindow") }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showNote(); return true }
    @objc func openDataFolder() { NSWorkspace.shared.open(store.directory) }
    @objc func openLoginSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") { NSWorkspace.shared.open(url) }
    }
    @objc func quitApp() { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        NotificationCenter.default.post(name: .blankNoteCommitEditing, object: nil)
        guard store.hasUnsavedChanges, !store.retrySave() else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "还有内容未能保存"
        alert.informativeText = "退出会丢失尚未写入磁盘的修改。请留在应用中解决保存问题，或明确选择仍然退出。"
        alert.addButton(withTitle: "留在应用")
        alert.addButton(withTitle: "仍然退出")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
    func applicationWillTerminate(_ notification: Notification) {
        guard panel != nil else { return }
        if state.collapsed { toggleCollapse() }
        panel.saveFrame(usingName: "BlankNoteWindow")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
