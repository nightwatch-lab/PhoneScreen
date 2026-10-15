#if canImport(VirtualDisplaySPI)
import VirtualDisplaySPI
#endif
import CoreGraphics
import Foundation
#if canImport(PhoneScreenCore)
import PhoneScreenCore
#endif

struct SessionError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

/// Owns the CGVirtualDisplay object. The panel exists only while this object
/// retains it.
final class VirtualDisplaySession {
    private var display: CGVirtualDisplay?
    private(set) var plan: VirtualModePlan?
    /// Called on main after each mode (re)selection so callers can re-assert origin.
    var onModeApplied: ((CGDirectDisplayID) -> Void)?

    var isConnected: Bool { display != nil }
    var displayID: CGDirectDisplayID { display?.displayID ?? 0 }

    private(set) var modeSet: VirtualModeSet?

    func connect(_ plan: VirtualModePlan, modeSet: VirtualModeSet? = nil) throws {
        disconnect()
        guard PhoneScreenVirtualDisplayAPIAvailable() else {
            throw SessionError(message: "这台 Mac 的 CoreGraphics 没有可用的 CGVirtualDisplay。")
        }
        var error: NSString?
        let name = "PhoneScreen \(plan.pixelWidth)x\(plan.pixelHeight)"
        let created: CGVirtualDisplay?
        if let modeSet, modeSet.supports(plan) {
            // Preferred mode first, then the rest, so HiDPI / 留边 can be switched in place.
            let first = plan.hiDPI
                ? VirtualModeSet.Size(width: plan.logicalWidth, height: plan.logicalHeight)
                : VirtualModeSet.Size(width: plan.pixelWidth, height: plan.pixelHeight)
            let ordered = [first] + modeSet.modes.filter { $0 != first }
            let mmW = 25.4 * Double(modeSet.maxPixelsWide) / Double(modeSet.ppi)
            let mmH = 25.4 * Double(modeSet.maxPixelsHigh) / Double(modeSet.ppi)
            created = PhoneScreenCreateVirtualDisplayWithModes(
                name,
                UInt32(modeSet.maxPixelsWide),
                UInt32(modeSet.maxPixelsHigh),
                mmW,
                mmH,
                ordered.map { NSNumber(value: $0.width) },
                ordered.map { NSNumber(value: $0.height) },
                Double(plan.refreshHz),
                1,
                &error
            )
            if created != nil { self.modeSet = modeSet }
        } else {
            created = PhoneScreenCreateVirtualDisplay(
                name,
                UInt32(plan.pixelWidth),
                UInt32(plan.pixelHeight),
                plan.millimetersWide,
                plan.millimetersHigh,
                UInt32(plan.pixelWidth),
                UInt32(plan.pixelHeight),
                Double(plan.refreshHz),
                plan.spiHiDPI,
                &error
            )
        }
        guard let created else {
            throw SessionError(message: (error as String?) ?? "创建虚拟显示器失败。")
        }
        display = created
        self.plan = plan
        if !waitUntilOnline(created.displayID) {
            disconnect()
            throw SessionError(message: "系统没有把虚拟显示器标为在线。")
        }
        guard display != nil else {
            throw SessionError(message: "连接过程中虚拟显示器被断开。")
        }
        _ = selectMode(displayID: created.displayID, plan: plan, exact: false)
        scheduleReassert(plan)
    }

    /// Switches HiDPI / 留边 on the existing display by changing its mode only.
    /// Returns false (display untouched) when the needed mode is not available,
    /// so the caller can fall back to recreating.
    func switchInPlace(to plan: VirtualModePlan) -> Bool {
        guard let display, let modeSet, modeSet.supports(plan) else {
            NSLog("PhoneScreen: in-place switch unavailable for \(plan.summary); will recreate")
            return false
        }
        let id = display.displayID
        guard selectMode(displayID: id, plan: plan, exact: true) else {
            NSLog("PhoneScreen: no exact CGDisplayMode for \(plan.summary); will recreate")
            return false
        }
        self.plan = plan
        NSLog("PhoneScreen: in-place mode switch to \(plan.summary) on display \(id)")
        onModeApplied?(id)
        scheduleReassert(plan)
        return true
    }

    private func scheduleReassert(_ plan: VirtualModePlan) {
        let id = displayID
        for delay in [0.5, 1.5, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.displayID == id, self.plan == plan else { return }
                if let cur = CGDisplayCopyDisplayMode(id), cur.width == plan.logicalWidth, cur.pixelWidth == plan.pixelWidth {
                    self.onModeApplied?(id)
                    return
                }
                _ = self.selectMode(displayID: id, plan: plan, exact: false)
                self.onModeApplied?(id)
            }
        }
    }

    func disconnect() {
        display = nil
        plan = nil
        modeSet = nil
    }

    private func waitUntilOnline(_ id: CGDirectDisplayID) -> Bool {
        for _ in 0 ..< 20 {
            if id != 0, CGDisplayIsOnline(id) != 0 {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return false
    }

    /// applySettings should already have selected the mode. This public-API
    /// pass picks a matching CGDisplayMode when the system exposes one.
    @discardableResult
    private func selectMode(displayID: CGDirectDisplayID, plan: VirtualModePlan, exact: Bool) -> Bool {
        let modes = Self.copyModes(displayID)
        let found = exact ? Self.exactMode(in: modes, plan: plan) : Self.bestMode(in: modes, plan: plan)
        guard let mode = found else { return false }
        if let cur = CGDisplayCopyDisplayMode(displayID), cur.width == mode.width, cur.height == mode.height,
           cur.pixelWidth == mode.pixelWidth, cur.pixelHeight == mode.pixelHeight {
            return true
        }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return false }
        if CGConfigureDisplayWithDisplayMode(config, displayID, mode, nil) == .success {
            if CGCompleteDisplayConfiguration(config, .forSession) == .success { return true }
            return CGDisplaySetDisplayMode(displayID, mode, nil) == .success
        }
        CGCancelDisplayConfiguration(config)
        return false
    }

    static func exactMode(in modes: [CGDisplayMode], plan: VirtualModePlan) -> CGDisplayMode? {
        let m = modes.filter {
            $0.pixelWidth == plan.pixelWidth && $0.pixelHeight == plan.pixelHeight
                && $0.width == plan.logicalWidth && $0.height == plan.logicalHeight
        }
        return m.first(where: { abs($0.refreshRate - Double(plan.refreshHz)) < 1.5 }) ?? m.first
    }

    static func copyModes(_ displayID: CGDirectDisplayID) -> [CGDisplayMode] {
        guard let array = CGDisplayCopyAllDisplayModes(displayID, [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary) else { return [] }
        let count = CFArrayGetCount(array)
        var modes: [CGDisplayMode] = []
        modes.reserveCapacity(count)
        for index in 0 ..< count {
            guard let pointer = CFArrayGetValueAtIndex(array, index) else { continue }
            let mode = Unmanaged<CGDisplayMode>.fromOpaque(pointer).takeUnretainedValue()
            modes.append(mode)
        }
        return modes
    }

    static func bestMode(in modes: [CGDisplayMode], plan: VirtualModePlan) -> CGDisplayMode? {
        if plan.hiDPI {
            let hi = modes.filter {
                $0.pixelWidth == plan.pixelWidth && $0.pixelHeight == plan.pixelHeight
                    && $0.width == plan.logicalWidth && $0.height == plan.logicalHeight
            }
            if let m = hi.first(where: { abs($0.refreshRate - Double(plan.refreshHz)) < 1.5 }) ?? hi.first {
                return m
            }
        }
        let pixels = modes.filter {
            $0.pixelWidth == plan.pixelWidth && $0.pixelHeight == plan.pixelHeight
        }
        if let matched = pixels.first(where: { abs($0.refreshRate - Double(plan.refreshHz)) < 1.5 }) {
            return matched
        }
        if let anyPixel = pixels.first {
            return anyPixel
        }
        return modes.first {
            $0.width == plan.logicalWidth && $0.height == plan.logicalHeight
        }
    }
}
