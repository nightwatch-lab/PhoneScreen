import AppKit
import Darwin
import Foundation
#if canImport(PhoneScreenCore)
import PhoneScreenCore
#endif

enum CLIClient {
    static func run(arguments: [String], json: Bool) -> Never {
        switch CommandParser.parseArguments(arguments) {
        case let .failure(error):
            if error == .usage {
                writeLine(error.message, to: stdout)
            } else {
                writeLine(error.message, to: stderr)
            }
            exit(error == .usage ? 0 : 2)
        case let .success(command):
            do {
                let result = try submit(command)
                emit(result, json: json)
                exit(result.ok ? 0 : 1)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                if json {
                    let failed = CommandResult(ok: false, message: message, connected: false, apiAvailable: false)
                    if let data = try? JSONEncoder().encode(failed), let text = String(data: data, encoding: .utf8) {
                        print(text)
                    }
                } else {
                    writeLine(message, to: stderr)
                }
                exit(3)
            }
        }
    }

    private static func submit(_ command: RemoteCommand) throws -> CommandResult {
        let path = PhoneScreenPaths.socketPath(uid: getuid())
        if !ControlServer.canConnect(path: path) {
            try launchGUI()
            var online = false
            for _ in 0 ..< 40 {
                if ControlServer.canConnect(path: path) {
                    online = true
                    break
                }
                usleep(100_000)
            }
            if !online {
                throw ControlServerError.socketFailed("PhoneScreen 没有在 4 秒内启动。请先打开菜单栏里的 PhoneScreen。")
            }
        }
        return try ControlServer.exchange(command, path: path)
    }

    private static func launchGUI() throws {
        if Bundle.main.bundleURL.pathExtension == "app" {
            let open = Process()
            open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            open.arguments = [Bundle.main.bundleURL.path]
            try open.run()
            open.waitUntilExit()
            if open.terminationStatus != 0 {
                throw ControlServerError.socketFailed("open 无法启动 PhoneScreen.app。")
            }
            return
        }
        let executable = URL(fileURLWithPath: CommandLine.arguments[0])
        let child = Process()
        child.executableURL = executable
        child.arguments = ["--gui"]
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        try child.run()
    }

    private static func writeLine(_ text: String, to file: UnsafeMutablePointer<FILE>) {
        let line = text.hasSuffix("\n") ? text : text + "\n"
        line.withCString { fputs($0, file) }
    }

    private static func emit(_ result: CommandResult, json: Bool) {
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(result), let text = String(data: data, encoding: .utf8) {
                print(text)
            }
            return
        }
        print(result.message)
        if result.connected {
            var detail: [String] = []
            if let width = result.width, let height = result.height {
                detail.append("像素 \(width)×\(height)")
            }
            if let logicalWidth = result.logicalWidth, let logicalHeight = result.logicalHeight {
                detail.append("逻辑 \(logicalWidth)×\(logicalHeight)")
            }
            if let hiDPI = result.hiDPI {
                detail.append(hiDPI ? "HiDPI" : "1×")
            }
            if let hz = result.hz {
                detail.append("\(hz) Hz")
            }
            if let role = result.role {
                detail.append(role)
            }
            if !detail.isEmpty {
                print(detail.joined(separator: " · "))
            }
        }
    }
}
