import Foundation

/// All CGVirtualDisplay modes registered on one display so HiDPI and
/// 防遮挡留边 can be switched in place (no teardown/recreate).
///
/// Entries are the sizes handed to CGVirtualDisplayMode. With the settings'
/// hiDPI flag set to 1, a W×H entry is offered as 1× W×H, and a (W/2)×(H/2)
/// entry is offered as HiDPI backed by W×H pixels.
public struct VirtualModeSet: Equatable {
    public struct Size: Equatable, Hashable {
        public let width: Int
        public let height: Int
        public init(width: Int, height: Int) { self.width = width; self.height = height }
    }

    /// Identity of the display: changing any of these needs a recreate.
    public let baseWidth: Int
    public let baseHeight: Int
    public let refreshHz: Int
    public let ppi: Int
    public let modes: [Size]
    public let maxPixelsWide: Int
    public let maxPixelsHigh: Int
    /// Plans for each (margin, hiDPI) combo, used for physical size and checks.
    public let plans: [VirtualModePlan]

    public static func make(width: Int, height: Int, refreshHz: Int, ppi: Int) throws -> VirtualModeSet {
        var plans: [VirtualModePlan] = []
        for margin in [false, true] {
            let s = SafeMargin.apply(width: width, height: height, enabled: margin)
            for hi in [false, true] {
                plans.append(try VirtualModePlan.make(width: s.width, height: s.height, hiDPI: hi, refreshHz: refreshHz, ppi: ppi))
            }
        }
        var modes: [Size] = []
        func add(_ s: Size) { if !modes.contains(s) { modes.append(s) } }
        for p in plans {
            add(Size(width: p.pixelWidth, height: p.pixelHeight))
            if p.hiDPI { add(Size(width: p.logicalWidth, height: p.logicalHeight)) }
        }
        let maxW = plans.map(\.pixelWidth).max() ?? width
        let maxH = plans.map(\.pixelHeight).max() ?? height
        return VirtualModeSet(baseWidth: width, baseHeight: height, refreshHz: refreshHz, ppi: ppi,
                              modes: modes, maxPixelsWide: maxW, maxPixelsHigh: maxH, plans: plans)
    }

    /// True when `plan` can be reached on this display by a mode switch only.
    public func supports(_ plan: VirtualModePlan) -> Bool {
        guard plan.refreshHz == refreshHz, plan.ppi == ppi else { return false }
        guard modes.contains(Size(width: plan.pixelWidth, height: plan.pixelHeight)) else { return false }
        if plan.hiDPI {
            return modes.contains(Size(width: plan.logicalWidth, height: plan.logicalHeight))
        }
        return true
    }
}
