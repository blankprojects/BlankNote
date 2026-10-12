import Foundation

enum LoginSettings {
    static let label = "org.blanknote.BlankNote"
    static var service: String { "gui/\(getuid())/\(label)" }
    static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
    static var isAvailable: Bool {
        ProcessInfo.processInfo.environment["BLANKNOTE_DATA_DIR"] == nil && FileManager.default.fileExists(atPath: agentURL.path)
    }

    static func isEnabled() throws -> Bool {
        let output = try run(["print-disabled", "gui/\(getuid())"])
        let pattern = "\"org\\.blanknote\\.BlankNote\"\\s*=>\\s*true"
        return output.range(of: pattern, options: .regularExpression) == nil
    }

    static func setEnabled(_ enabled: Bool) throws {
        _ = try run([enabled ? "enable" : "disable", service])
    }

    private static func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "BlankNote.LoginSettings", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }
        return output
    }
}
