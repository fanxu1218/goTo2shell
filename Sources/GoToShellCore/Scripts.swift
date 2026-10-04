import Foundation
import Carbon

public enum TerminalChoice: String, CaseIterable {
    case terminal, iterm

    public var name: String { self == .terminal ? "Terminal" : "iTerm2" }
    public var bundleIdentifier: String {
        self == .terminal ? "com.apple.Terminal" : "com.googlecode.iterm2"
    }

    public var script: String {
        switch self {
        case .terminal:
            return """
            on run argv
                tell application id "com.apple.Terminal"
                    do script (item 1 of argv)
                    activate
                end tell
            end run
            """
        case .iterm:
            return """
            on run argv
                tell application id "com.googlecode.iterm2"
                    set newWindow to (create window with default profile)
                    tell current session of newWindow
                        write text (item 1 of argv)
                    end tell
                    activate
                end tell
            end run
            """
        }
    }
}

public enum Scripts {
    public static func finderDirectory(preferSelection: Bool) -> String {
        """
        tell application id "com.apple.finder"
            if \(preferSelection ? "true" : "false") then
                set chosenItems to selection
                if (count of chosenItems) > 1 then
                    error "一次请选择一个文件或文件夹。" number 1001
                end if
                if (count of chosenItems) is 1 then
                    return POSIX path of ((item 1 of chosenItems) as alias)
                end if
            end if
            if (count of Finder windows) is 0 then
                return POSIX path of (desktop as alias)
            end if
            try
                return POSIX path of ((target of front Finder window) as alias)
            on error
                error "当前 Finder 页面没有本机目录。请打开实际文件夹后重试。" number 1002
            end try
        end tell
        """
    }
}

public enum AppleScriptRunner {
    /// Send values as event arguments, never interpolate paths into AppleScript source.
    public static func run(_ source: String, arguments: [String]? = nil) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw ShellError.script(-1, "无法创建自动化脚本。")
        }
        var details: NSDictionary?
        let result: NSAppleEventDescriptor
        if let arguments {
            let event = NSAppleEventDescriptor(
                eventClass: AEEventClass(kCoreEventClass),
                eventID: AEEventID(kAEOpenApplication),
                targetDescriptor: nil,
                returnID: AEReturnID(kAutoGenerateReturnID),
                transactionID: AETransactionID(kAnyTransactionID)
            )
            let list = NSAppleEventDescriptor.list()
            for (index, value) in arguments.enumerated() {
                list.insert(NSAppleEventDescriptor(string: value), at: index + 1)
            }
            event.setParam(list, forKeyword: AEKeyword(keyDirectObject))
            result = script.executeAppleEvent(event, error: &details)
        } else {
            result = script.executeAndReturnError(&details)
        }
        if let details {
            let code = (details[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? -1
            let message = details[NSAppleScript.errorMessage] as? String ?? "自动化失败。"
            throw ShellError.script(code, message)
        }
        return result
    }
}
