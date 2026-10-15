import Foundation

/// Bounds for user-entered virtual display settings.
public enum DisplayLimits {
    public static let minEdge = 240
    public static let maxEdge = 8192
    public static let refreshRates = [30, 60, 120]
    public static let minPPI = 72
    public static let maxPPI = 800

    public static func dimensionMessage(edge: String, value: Int) -> String {
        "\(edge)必须在 \(minEdge) 和 \(maxEdge) 之间，当前是 \(value)。"
    }
}
