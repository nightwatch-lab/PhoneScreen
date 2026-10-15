import Foundation

public enum PlanError: Error, Equatable {
    case dimensionOutOfRange(edge: String, value: Int)
    case refreshUnsupported(Int)
    case ppiOutOfRange(Int)

    public var message: String {
        switch self {
        case let .dimensionOutOfRange(edge, value):
            return DisplayLimits.dimensionMessage(edge: edge, value: value)
        case let .refreshUnsupported(hz):
            return "刷新率只支持 \(DisplayLimits.refreshRates.map(String.init).joined(separator: " / ")) Hz，当前是 \(hz)。"
        case let .ppiOutOfRange(ppi):
            return "PPI 必须在 \(DisplayLimits.minPPI) 和 \(DisplayLimits.maxPPI) 之间，当前是 \(ppi)。"
        }
    }
}

/// How a requested pixel size is turned into a CGVirtualDisplay mode.
///
/// Width and height are the framebuffer pixels the phone should match.
/// With HiDPI on, the mode submitted to CoreGraphics is half of that in each
/// axis and the private `hiDPI` flag is 1. Public write-ups of this SPI
/// (Chromium's virtual display helper, DeskPad) treat that flag as "back the
/// mode with a 2× framebuffer", not as the number 2.
public struct VirtualModePlan: Equatable {
    public let requestedWidth: Int
    public let requestedHeight: Int
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let logicalWidth: Int
    public let logicalHeight: Int
    public let hiDPI: Bool
    public let refreshHz: Int
    public let ppi: Int
    public let millimetersWide: Double
    public let millimetersHigh: Double
    public let roundedToEven: Bool

    public var spiHiDPI: UInt32 { hiDPI ? 1 : 0 }

    public var summary: String {
        let scale = hiDPI ? "HiDPI 2×" : "1×"
        return "\(pixelWidth)×\(pixelHeight) \(scale) @ \(refreshHz) Hz"
    }

    public static func make(
        width: Int,
        height: Int,
        hiDPI: Bool,
        refreshHz: Int,
        ppi: Int
    ) throws -> VirtualModePlan {
        try validateDimension("宽度", width)
        try validateDimension("高度", height)
        guard DisplayLimits.refreshRates.contains(refreshHz) else {
            throw PlanError.refreshUnsupported(refreshHz)
        }
        guard (DisplayLimits.minPPI ... DisplayLimits.maxPPI).contains(ppi) else {
            throw PlanError.ppiOutOfRange(ppi)
        }

        var pixelWidth = width
        var pixelHeight = height
        var rounded = false
        if hiDPI {
            if pixelWidth % 2 != 0 {
                pixelWidth += 1
                rounded = true
            }
            if pixelHeight % 2 != 0 {
                pixelHeight += 1
                rounded = true
            }
        }

        let logicalWidth = hiDPI ? pixelWidth / 2 : pixelWidth
        let logicalHeight = hiDPI ? pixelHeight / 2 : pixelHeight
        let millimetersWide = 25.4 * Double(pixelWidth) / Double(ppi)
        let millimetersHigh = 25.4 * Double(pixelHeight) / Double(ppi)

        return VirtualModePlan(
            requestedWidth: width,
            requestedHeight: height,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            logicalWidth: logicalWidth,
            logicalHeight: logicalHeight,
            hiDPI: hiDPI,
            refreshHz: refreshHz,
            ppi: ppi,
            millimetersWide: millimetersWide,
            millimetersHigh: millimetersHigh,
            roundedToEven: rounded
        )
    }

    private static func validateDimension(_ edge: String, _ value: Int) throws {
        guard (DisplayLimits.minEdge ... DisplayLimits.maxEdge).contains(value) else {
            throw PlanError.dimensionOutOfRange(edge: edge, value: value)
        }
    }
}
