import Foundation

public enum RemoteAction: String, Codable, Equatable, CaseIterable {
    case connect
    case disconnect
    case swap
    case main
    case mirror
    case restore
    case status
}

/// One command from the URL scheme, the CLI, or the local socket.
public struct RemoteCommand: Codable, Equatable {
    public var action: RemoteAction
    public var width: Int?
    public var height: Int?
    public var hiDPI: Bool?
    public var hz: Int?
    public var ppi: Int?

    public init(
        action: RemoteAction,
        width: Int? = nil,
        height: Int? = nil,
        hiDPI: Bool? = nil,
        hz: Int? = nil,
        ppi: Int? = nil
    ) {
        self.action = action
        self.width = width
        self.height = height
        self.hiDPI = hiDPI
        self.hz = hz
        self.ppi = ppi
    }

    /// Fill omitted connect fields from the current settings, then validate.
    public func settings(applyingTo base: AppSettings) throws -> AppSettings {
        guard action == .connect else { return base }
        var next = base
        if let width { next.width = width }
        if let height { next.height = height }
        if let hiDPI { next.hiDPI = hiDPI }
        if let hz { next.refreshHz = hz }
        if let ppi { next.ppi = ppi }
        _ = try next.plan()
        return next
    }
}

public struct CommandResult: Codable, Equatable {
    public var ok: Bool
    public var message: String
    public var connected: Bool
    public var width: Int?
    public var height: Int?
    public var logicalWidth: Int?
    public var logicalHeight: Int?
    public var hiDPI: Bool?
    public var hz: Int?
    public var ppi: Int?
    public var displayID: UInt32?
    public var role: String?
    public var apiAvailable: Bool
    public var roundedToEven: Bool?

    public init(
        ok: Bool,
        message: String,
        connected: Bool,
        width: Int? = nil,
        height: Int? = nil,
        logicalWidth: Int? = nil,
        logicalHeight: Int? = nil,
        hiDPI: Bool? = nil,
        hz: Int? = nil,
        ppi: Int? = nil,
        displayID: UInt32? = nil,
        role: String? = nil,
        apiAvailable: Bool,
        roundedToEven: Bool? = nil
    ) {
        self.ok = ok
        self.message = message
        self.connected = connected
        self.width = width
        self.height = height
        self.logicalWidth = logicalWidth
        self.logicalHeight = logicalHeight
        self.hiDPI = hiDPI
        self.hz = hz
        self.ppi = ppi
        self.displayID = displayID
        self.role = role
        self.apiAvailable = apiAvailable
        self.roundedToEven = roundedToEven
    }
}

public enum CommandParseError: Error, Equatable {
    case empty
    case unknownAction(String)
    case missingValue(String)
    case notAnInteger(String)
    case invalidHiDPI(String)
    case connectNeedsSize
    case usage

    public var message: String {
        switch self {
        case .empty:
            return "没有要执行的命令。"
        case let .unknownAction(name):
            return "不认识的命令「\(name)」。\n\(CommandParser.usageText)"
        case let .missingValue(flag):
            return "\(flag) 后面需要一个数值。"
        case let .notAnInteger(token):
            return "「\(token)」不是整数。"
        case let .invalidHiDPI(token):
            return "hidpi 只能是 1/0、true/false 或 on/off，收到「\(token)」。"
        case .connectNeedsSize:
            return "connect 需要同时给出宽度和高度，例如 --width 1170 --height 2532。"
        case .usage:
            return CommandParser.usageText
        }
    }
}
