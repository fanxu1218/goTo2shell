import XCTest
import Foundation
import Darwin
@testable import GoToShellCore

final class GoToShellCoreTests: XCTestCase {
    private var fixture: URL!

    override func setUpWithError() throws {
        fixture = FileManager.default.temporaryDirectory.appendingPathComponent("GoToShell-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: fixture)
    }

    func testDirectoriesAndFilesResolveToCorrectFolder() throws {
        let directory = fixture.appendingPathComponent("中文 project's folder")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("notes.txt")
        try Data("hello".utf8).write(to: file)
        XCTAssertEqual(try DirectoryResolver.resolve([directory]).path, directory.path)
        XCTAssertEqual(try DirectoryResolver.resolve([file]).path, directory.path)
    }

    func testSymlinkSpellingIsPreserved() throws {
        let link = fixture.appendingPathComponent("shortcut")
        let target = fixture.appendingPathComponent("real")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertEqual(try DirectoryResolver.resolve([link]).path, link.path)
    }

    func testInvalidInputsAreRejected() {
        XCTAssertThrowsError(try DirectoryResolver.resolve([]))
        XCTAssertThrowsError(try DirectoryResolver.resolve([fixture, fixture]))
        XCTAssertThrowsError(try DirectoryResolver.resolve([URL(string: "https://example.com")!]))
        XCTAssertThrowsError(try DirectoryResolver.resolve([fixture.appendingPathComponent("missing")]))
        for path in ["/tmp/new\nline", "/tmp/tab\tname", "/tmp/return\rname", "/tmp/null\0name", "/tmp/\u{7f}"] {
            XCTAssertThrowsError(try DirectoryResolver.validatePath(path))
        }
    }

    func testQuotedPathsActuallyChangeDirectoryWithoutExecutingFilename() throws {
        let names = [
            "space folder", "中文🚀", "quote'and\"double", "semi;colon & pipe|",
            "$(touch INJECTION_MARKER)", "`touch INJECTION_MARKER`", "'; touch INJECTION_MARKER; '",
            "back\\slash", "-leading dash"
        ]
        for name in names {
            let directory = fixture.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let command = try DirectoryResolver.changeDirectoryCommand(directory)
            for shell in ["/bin/sh", "/bin/bash", "/bin/zsh"] {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: shell)
                process.arguments = ["-c", command + " && /bin/pwd -P"]
                process.currentDirectoryURL = fixture
                process.standardOutput = pipe
                process.standardError = pipe
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                XCTAssertEqual(process.terminationStatus, 0, "\(shell): \(name)")
                let canonicalPath = try XCTUnwrap(realpath(directory.path, nil))
                defer { free(canonicalPath) }
                XCTAssertEqual(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines),
                               String(cString: canonicalPath), "\(shell): \(name)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.appendingPathComponent("INJECTION_MARKER").path))
    }

    func testAppleScriptArgumentsRemainData() throws {
        let value = "中文 ' \" \\ $(touch marker); tell application \"Finder\""
        let result = try AppleScriptRunner.run("on run argv\nreturn item 1 of argv\nend run", arguments: [value])
        XCTAssertEqual(result.stringValue, value)
    }

    func testAppleScriptErrorsAreSurfaced() {
        XCTAssertThrowsError(try AppleScriptRunner.run("error \"expected error\" number 1005")) { error in
            guard case ShellError.script(let code, _) = error else { return XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(code, 1005)
        }
    }

    func testFinderAndTerminalScriptsCompileWithoutRunningAutomation() {
        for source in [Scripts.finderDirectory(preferSelection: false),
                       Scripts.finderDirectory(preferSelection: true), TerminalChoice.terminal.script] {
            var error: NSDictionary?
            let script = NSAppleScript(source: source)!
            XCTAssertTrue(script.compileAndReturnError(&error), "\(String(describing: error))")
        }
    }
}
