import AppKit
import GoToShellCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = UserDefaults.standard
    private var statusItem: NSStatusItem!
    private var settings: SettingsWindowController?
    private var launchWork: DispatchWorkItem?
    private var isOpening = false
    private var receivedDocumentEvent = false

    private var terminal: TerminalChoice {
        TerminalChoice(rawValue: preferences.string(forKey: "terminal") ?? "") ?? .terminal
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        makeMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "GoToShell")
        statusItem.button?.toolTip = "GoToShell · 在 Finder 当前目录打开终端"
        let menu = NSMenu()
        menu.addItem(withTitle: "打开 Finder 当前目录", action: #selector(openFinder), keyEquivalent: "")
        menu.addItem(withTitle: "选择文件夹…", action: #selector(chooseFolder), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置与安装引导…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "退出 GoToShell", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu

        if !preferences.bool(forKey: "configured") || CommandLine.arguments.contains("--settings") {
            showSettings()
        } else if launchWork == nil && !receivedDocumentEvent {
            scheduleFinderOpen()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Finder toolbar launches reuse the running app. Ignore visibility of settings.
        if preferences.bool(forKey: "configured") { scheduleFinderOpen() }
        else { showSettings() }
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedDocumentEvent = true
        launchWork?.cancel()
        launchWork = nil
        if !preferences.bool(forKey: "configured") { showSettings(); return }
        DispatchQueue.main.async { [weak self] in self?.openDirectory(urls) }
    }

    private func makeMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 GoToShell", action: #selector(quit), keyEquivalent: "q").target = self
        appItem.submenu = appMenu
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func scheduleFinderOpen() {
        launchWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.launchWork = nil
            self?.openFinder()
        }
        launchWork = work
        // Give Launch Services time to deliver an open-document event for dropped files.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    @objc func openFinder() {
        guard !isOpening else { return }
        isOpening = true
        defer { isOpening = false }
        do {
            let result = try AppleScriptRunner.run(Scripts.finderDirectory(
                preferSelection: preferences.bool(forKey: "preferSelection")
            ))
            guard let path = result.stringValue, !path.isEmpty else {
                throw ShellError.script(-1, "Finder 没有返回有效目录。")
            }
            try launchTerminal(at: DirectoryResolver.resolve([URL(fileURLWithPath: path)]))
        } catch { showError(error) }
    }

    private func openDirectory(_ urls: [URL]) {
        guard !isOpening else { return }
        isOpening = true
        defer { isOpening = false }
        do { try launchTerminal(at: DirectoryResolver.resolve(urls)) }
        catch { showError(error) }
    }

    private func launchTerminal(at directory: URL) throws {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleIdentifier) != nil else {
            throw ShellError.unavailableTerminal(terminal.name)
        }
        let command = try DirectoryResolver.changeDirectoryCommand(directory)
        _ = try AppleScriptRunner.run(terminal.script, arguments: [command])
        settings?.setStatus("已在 \(terminal.name) 打开：\(directory.path)", isError: false)
    }

    @objc func chooseFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "选择要在终端打开的文件夹"
        panel.prompt = "打开终端"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { openDirectory([url]) }
    }

    @objc func showSettings() {
        if settings == nil {
            settings = SettingsWindowController(preferences: preferences)
            settings?.onOpenFinder = { [weak self] in self?.openFinder() }
            settings?.onChooseFolder = { [weak self] in self?.chooseFolder() }
        }
        settings?.refresh()
        settings?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settings?.window?.makeKeyAndOrderFront(nil)
    }

    private func showError(_ error: Error) {
        settings?.setStatus(error.localizedDescription, isError: true)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "暂时无法打开终端"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "打开设置")
        if alert.runModal() == .alertSecondButtonReturn { showSettings() }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
