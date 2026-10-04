import AppKit
import GoToShellCore

final class SettingsWindowController: NSWindowController {
    var onOpenFinder: (() -> Void)?
    var onChooseFolder: (() -> Void)?
    private let preferences: UserDefaults
    private let terminalPicker = NSPopUpButton()
    private let selectionCheckbox = NSButton(checkboxWithTitle: "优先打开 Finder 中选中的项目", target: nil, action: nil)
    private let availabilityLabel = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(wrappingLabelWithString: "")

    init(preferences: UserDefaults) {
        self.preferences = preferences
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 650),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.title = "GoToShell"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func refresh() {
        let choice = TerminalChoice(rawValue: preferences.string(forKey: "terminal") ?? "") ?? .terminal
        terminalPicker.selectItem(at: TerminalChoice.allCases.firstIndex(of: choice) ?? 0)
        selectionCheckbox.state = preferences.bool(forKey: "preferSelection") ? .on : .off
        updateAvailability()
    }

    func setStatus(_ text: String, isError: Bool) {
        statusLabel.stringValue = text
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28)
        ])

        let header = NSStackView()
        header.orientation = .horizontal
        header.spacing = 16
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "终端")
        icon.contentTintColor = .systemGreen
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 42, weight: .medium)
        icon.widthAnchor.constraint(equalToConstant: 58).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 58).isActive = true
        header.addArrangedSubview(icon)
        let titles = NSStackView()
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 4
        titles.addArrangedSubview(label("GoToShell", size: 28, weight: .bold))
        titles.addArrangedSubview(label("从 Finder 到终端，只需一次点击。", size: 13, color: .secondaryLabelColor))
        header.addArrangedSubview(titles)
        stack.addArrangedSubview(header)
        addSeparator(to: stack)

        stack.addArrangedSubview(label("选择终端", size: 15, weight: .semibold))
        terminalPicker.addItems(withTitles: TerminalChoice.allCases.map(\.name))
        terminalPicker.target = self
        terminalPicker.action = #selector(savePreferences)
        terminalPicker.widthAnchor.constraint(equalToConstant: 220).isActive = true
        stack.addArrangedSubview(terminalPicker)
        availabilityLabel.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(availabilityLabel)

        selectionCheckbox.target = self
        selectionCheckbox.action = #selector(savePreferences)
        stack.addArrangedSubview(selectionCheckbox)
        stack.addArrangedSubview(label(
            "默认打开当前窗口目录。启用后，选中文件夹会打开该文件夹；选中文件会打开其所在目录。每次创建新终端窗口。",
            size: 12, color: .secondaryLabelColor
        ))
        addSeparator(to: stack)

        stack.addArrangedSubview(label("添加到 Finder 工具栏", size: 15, weight: .semibold))
        stack.addArrangedSubview(label(
            "1. 将 GoToShell.app 放到固定位置，例如「应用程序」。\n2. 点击下方按钮，在 Finder 中显示应用。\n3. 按住 ⌘ Command，将应用拖到 Finder 顶部工具栏。",
            size: 13
        ))
        let reveal = NSButton(title: "在 Finder 中显示应用", target: self, action: #selector(revealApplication))
        reveal.bezelStyle = .rounded
        stack.addArrangedSubview(reveal)
        stack.addArrangedSubview(label(
            "首次打开时，请允许控制 Finder 和终端。之后可从菜单栏的终端图标重新打开设置。",
            size: 12, color: .secondaryLabelColor
        ))
        addSeparator(to: stack)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        let test = NSButton(title: "打开 Finder 当前目录", target: self, action: #selector(testFinder))
        test.bezelStyle = .rounded
        let choose = NSButton(title: "选择文件夹…", target: self, action: #selector(chooseFolder))
        choose.bezelStyle = .rounded
        let done = NSButton(title: "完成", target: self, action: #selector(finishSetup))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        buttons.addArrangedSubview(test)
        buttons.addArrangedSubview(choose)
        buttons.addArrangedSubview(done)
        stack.addArrangedSubview(buttons)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.stringValue = "准备就绪 · macOS 13 及以上"
        stack.addArrangedSubview(statusLabel)
        for view in stack.arrangedSubviews {
            if view is NSTextField || view is NSBox || view === header {
                view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }
        // Fit wrapped labels and accommodate both system appearance modes.
        stack.layoutSubtreeIfNeeded()
        let height = max(650, stack.fittingSize.height + 56)
        window?.setContentSize(NSSize(width: 560, height: height))
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular,
                       color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.isSelectable = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    private func addSeparator(to stack: NSStackView) {
        let separator = NSBox()
        separator.boxType = .separator
        stack.addArrangedSubview(separator)
    }

    @objc private func savePreferences() {
        let choice = TerminalChoice.allCases[terminalPicker.indexOfSelectedItem]
        preferences.set(choice.rawValue, forKey: "terminal")
        preferences.set(selectionCheckbox.state == .on, forKey: "preferSelection")
        updateAvailability()
    }

    private func updateAvailability() {
        let choice = TerminalChoice.allCases[max(0, terminalPicker.indexOfSelectedItem)]
        let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: choice.bundleIdentifier) != nil
        availabilityLabel.stringValue = installed ? "已安装 \(choice.name)" : "尚未安装 \(choice.name)。安装后即可使用。"
        availabilityLabel.textColor = installed ? .secondaryLabelColor : .systemOrange
    }

    @objc private func revealApplication() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    @objc private func testFinder() { savePreferences(); onOpenFinder?() }
    @objc private func chooseFolder() { savePreferences(); onChooseFolder?() }
    @objc private func finishSetup() {
        savePreferences()
        let choice = TerminalChoice.allCases[terminalPicker.indexOfSelectedItem]
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: choice.bundleIdentifier) != nil else {
            setStatus("请先安装 \(choice.name)，或选择 Terminal。", isError: true)
            return
        }
        preferences.set(true, forKey: "configured")
        window?.close()
    }
}
