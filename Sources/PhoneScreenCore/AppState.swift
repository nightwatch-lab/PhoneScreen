import Foundation

public struct AppSettings: Codable, Equatable {
    public var width: Int
    public var height: Int
    public var hiDPI: Bool
    public var refreshHz: Int
    public var ppi: Int

    public init(
        width: Int,
        height: Int,
        hiDPI: Bool,
        refreshHz: Int,
        ppi: Int
    ) {
        self.width = width
        self.height = height
        self.hiDPI = hiDPI
        self.refreshHz = refreshHz
        self.ppi = ppi
    }

    /// iPhone 17e portrait, HiDPI on, 60 Hz. Not a fixed resolution: the user
    /// can overwrite every field.
    public static let iPhone17eDefault = AppSettings(
        width: PhonePresets.iPhone17ePortrait.width,
        height: PhonePresets.iPhone17ePortrait.height,
        hiDPI: true,
        refreshHz: 60,
        ppi: PhonePresets.iPhone17ePortrait.ppi
    )

    public mutating func swapOrientation() {
        swap(&width, &height)
    }

    public mutating func applyPreset(_ preset: PhonePreset) {
        width = preset.width
        height = preset.height
        ppi = preset.ppi
    }

    public mutating func clamp() {
        width = width.clamped(to: DisplayLimits.minEdge ... DisplayLimits.maxEdge)
        height = height.clamped(to: DisplayLimits.minEdge ... DisplayLimits.maxEdge)
        ppi = ppi.clamped(to: DisplayLimits.minPPI ... DisplayLimits.maxPPI)
        if !DisplayLimits.refreshRates.contains(refreshHz) {
            refreshHz = 60
        }
    }

    public func plan() throws -> VirtualModePlan {
        try VirtualModePlan.make(
            width: width,
            height: height,
            hiDPI: hiDPI,
            refreshHz: refreshHz,
            ppi: ppi
        )
    }
}

public struct PhoneScreenState: Codable, Equatable {
    public var settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public static let fresh = PhoneScreenState(settings: .iPhone17eDefault)

    public mutating func clamp() {
        settings.clamp()
    }
}

public struct StateLoad {
    public var state: PhoneScreenState
    public var warning: String?
}

public final class StateStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> StateLoad {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return StateLoad(state: .fresh, warning: nil)
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            var state = try decoder.decode(PhoneScreenState.self, from: data)
            state.clamp()
            return StateLoad(state: state, warning: nil)
        } catch {
            return StateLoad(
                state: .fresh,
                warning: "无法读取已保存的设置，已改用 iPhone 17e 默认值。"
            )
        }
    }

    public func save(_ state: PhoneScreenState) throws {
        var copy = state
        copy.clamp()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(copy)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}

public enum PhoneScreenPaths {
    public static func supportDirectory(home: URL) -> URL {
        home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("PhoneScreen", isDirectory: true)
    }

    public static func stateFileURL(home: URL) -> URL {
        supportDirectory(home: home).appendingPathComponent("state.json")
    }

    /// Short path: sockaddr_un.sun_path is only 104 bytes, and Application Support
    /// paths for long home directories do not fit.
    public static func socketPath(uid: UInt32) -> String {
        "/tmp/phonescreen-\(uid).sock"
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
