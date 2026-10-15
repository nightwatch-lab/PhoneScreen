import Foundation

public enum CommandParser {
    public static let usageText = """
    用法:
      phonescreen connect [--width <像素> --height <像素>] [--hidpi|--no-hidpi] [--hz 30|60|120] [--ppi <数值>]
      phonescreen disconnect
      phonescreen swap
      phonescreen main
      phonescreen mirror
      phonescreen restore
      phonescreen status
      phonescreen help

    全局选项: --json

    URL（需要已经用 PhoneScreen.app 注册 phonescreen://）:
      phonescreen://connect?w=1170&h=2532&hidpi=1&hz=60
      phonescreen://disconnect
      phonescreen://swap
      phonescreen://main
      phonescreen://mirror
      phonescreen://restore
    """

    public static func parseURL(_ url: URL) -> Result<RemoteCommand, CommandParseError> {
        guard url.scheme?.lowercased() == "phonescreen" else {
            return .failure(.unknownAction(url.scheme ?? ""))
        }
        let actionName = actionName(from: url)
        guard let action = RemoteAction(rawValue: actionName) else {
            return .failure(.unknownAction(actionName.isEmpty ? url.absoluteString : actionName))
        }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var command = RemoteCommand(action: action)
        do {
            for item in items {
                let key = item.name.lowercased()
                let value = item.value ?? ""
                switch key {
                case "w", "width":
                    command.width = try integer(value, label: key)
                case "h", "height":
                    command.height = try integer(value, label: key)
                case "hz", "refresh", "refreshrate":
                    command.hz = try integer(value, label: key)
                case "ppi":
                    command.ppi = try integer(value, label: key)
                case "hidpi", "hi-dpi":
                    command.hiDPI = try hiDPIFlag(value)
                default:
                    continue
                }
            }
        } catch let error as CommandParseError {
            return .failure(error)
        } catch {
            return .failure(.usage)
        }
        if let error = partialSize(command) { return .failure(error) }
        return .success(command)
    }

    public static func parseArguments(_ arguments: [String]) -> Result<RemoteCommand, CommandParseError> {
        guard let first = arguments.first else { return .failure(.empty) }
        if first == "help" || first == "--help" || first == "-h" {
            return .failure(.usage)
        }
        guard let action = RemoteAction(rawValue: first) else {
            return .failure(.unknownAction(first))
        }
        var command = RemoteCommand(action: action)
        var index = 1
        do {
            while index < arguments.count {
                let token = arguments[index]
                switch token {
                case "--width", "-w":
                    command.width = try takeInt(arguments, index: &index, flag: token)
                case "--height", "-h":
                    command.height = try takeInt(arguments, index: &index, flag: token)
                case "--hz", "--refresh":
                    command.hz = try takeInt(arguments, index: &index, flag: token)
                case "--ppi":
                    command.ppi = try takeInt(arguments, index: &index, flag: token)
                case "--hidpi":
                    command.hiDPI = true
                case "--no-hidpi":
                    command.hiDPI = false
                default:
                    return .failure(.unknownAction(token))
                }
                index += 1
            }
        } catch let error as CommandParseError {
            return .failure(error)
        } catch {
            return .failure(.usage)
        }
        if let error = partialSize(command) { return .failure(error) }
        return .success(command)
    }

    /// connect 可以省略宽高（沿用已保存的设置），但不能只给一边。
    private static func partialSize(_ command: RemoteCommand) -> CommandParseError? {
        guard command.action == .connect else { return nil }
        if (command.width == nil) != (command.height == nil) {
            return .connectNeedsSize
        }
        return nil
    }

    public static func parseHiDPI(_ token: String) -> Bool? {
        switch token.lowercased() {
        case "1", "true", "yes", "on": return true
        case "0", "false", "no", "off": return false
        default: return nil
        }
    }

    private static func actionName(from url: URL) -> String {
        if let host = url.host, !host.isEmpty {
            return host.lowercased()
        }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.lowercased()
    }

    private static func integer(_ value: String, label: String) throws -> Int {
        guard let number = Int(value) else { throw CommandParseError.notAnInteger(value.isEmpty ? label : value) }
        return number
    }

    private static func hiDPIFlag(_ value: String) throws -> Bool {
        guard let flag = parseHiDPI(value) else { throw CommandParseError.invalidHiDPI(value) }
        return flag
    }

    private static func takeInt(_ arguments: [String], index: inout Int, flag: String) throws -> Int {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else { throw CommandParseError.missingValue(flag) }
        index = valueIndex
        return try integer(arguments[valueIndex], label: flag)
    }
}
