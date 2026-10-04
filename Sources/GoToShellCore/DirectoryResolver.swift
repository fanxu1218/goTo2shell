import Foundation

public enum ShellError: LocalizedError {
    case nonFileURL
    case missingPath(String)
    case controlCharacter
    case multipleItems
    case finderLocationUnavailable
    case script(Int, String)
    case unavailableTerminal(String)

    public var errorDescription: String? {
        switch self {
        case .nonFileURL: return "请选择本机文件或文件夹。"
        case .missingPath(let path): return "目录不存在或暂时无法访问：\(path)"
        case .controlCharacter: return "目录路径包含换行或控制字符，无法安全地发送给终端。"
        case .multipleItems: return "一次请选择一个文件或文件夹。"
        case .finderLocationUnavailable:
            return "「最近使用」和搜索结果是汇总页面，没有固定目录。请进入实际文件夹后重试；也可以在设置中启用「优先打开 Finder 中选中的项目」，选中一个文件后打开其所在目录，或直接选择文件夹。"
        case .script(let code, let message):
            if code == -1743 {
                return "请在系统设置 → 隐私与安全性 → 自动化中，允许 GoToShell 控制 Finder 和所选终端，然后重试。"
            }
            return "无法打开目录（\(code)）：\(message)"
        case .unavailableTerminal(let name): return "未找到 \(name)，请先安装，或在设置中选择系统 Terminal。"
        }
    }
}

public enum DirectoryResolver {
    /// Files resolve to their containing folder. Directory URLs retain symlink spelling.
    public static func resolve(_ urls: [URL]) throws -> URL {
        guard urls.count == 1 else { throw ShellError.multipleItems }
        let url = urls[0]
        guard url.isFileURL else { throw ShellError.nonFileURL }
        let normalized = url.standardizedFileURL
        try validatePath(normalized.path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalized.path, isDirectory: &isDirectory) else {
            throw ShellError.missingPath(normalized.path)
        }
        return isDirectory.boolValue ? normalized : normalized.deletingLastPathComponent()
    }

    public static func validatePath(_ path: String) throws {
        guard !path.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
            throw ShellError.controlCharacter
        }
    }

    public static func shellQuote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func changeDirectoryCommand(_ directory: URL) throws -> String {
        try validatePath(directory.path)
        // An absolute, quoted argument works in sh, bash, zsh and fish.
        return "cd " + shellQuote(directory.path)
    }
}
