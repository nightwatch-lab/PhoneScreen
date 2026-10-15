import CoreGraphics
import Foundation
#if canImport(PhoneScreenCore)
import PhoneScreenCore
#endif

enum ArrangementError: LocalizedError {
    case beginFailed(CGError)
    case stepFailed(CGError)
    case missingDisplay
    case virtualIsMain

    var errorDescription: String? {
        switch self {
        case let .beginFailed(code):
            return "无法开始显示器配置（\(code.rawValue)）。"
        case let .stepFailed(code):
            return "显示器配置被系统拒绝（\(code.rawValue)）。"
        case .missingDisplay:
            return "找不到虚拟显示器。"
        case .virtualIsMain:
            return "虚拟屏已经是主显示器。先点「恢复原始排列」，再镜像。"
        }
    }
}

/// Session-scoped display arrangement.
///
/// Uses only the public configuration transaction:
/// CGBeginDisplayConfiguration / CGConfigureDisplayOrigin /
/// CGConfigureDisplayMirrorOfDisplay / CGCompleteDisplayConfiguration(..., .forSession).
/// `.permanently` is never used, and this type does not read or write WindowServer plists.
final class DisplayArrangement {
    private(set) var baseline: [DisplayFrame]?

    var hasBaseline: Bool { baseline != nil }

    func captureBaseline() {
        baseline = Self.onlineFrames()
    }

    func clearBaseline() {
        baseline = nil
        target = nil
    }

    private(set) var target: DisplayFrame?

    /// Put the virtual display at its target spot (saved or right of the
    /// rightmost display). Physical displays are put back at their
    /// pre-connect origins only if the system moved them.
    func placeVirtual(_ virtualID: CGDirectDisplayID, saved: (x: Double, y: Double)?) throws {
        guard let current = Self.frame(for: virtualID) else { throw ArrangementError.missingDisplay }
        let physical = (baseline ?? Self.onlineFrames()).filter { $0.id != virtualID }
        let frame = DisplayGeometry.placement(
            id: virtualID, width: current.width, height: current.height,
            others: physical, saved: saved)
        target = frame
        try assertPlacement(virtualID)
    }

    /// Re-apply the remembered target (used after mode changes, which can
    /// make macOS re-arrange). No-op when nothing needs to move.
    func assertPlacement(_ virtualID: CGDirectDisplayID) throws {
        guard var frame = target, let current = Self.frame(for: virtualID) else { return }
        let physical = (baseline ?? []).filter { $0.id != virtualID }
        // Size may change after a HiDPI mode switch; keep origin, re-validate.
        frame.width = current.width
        frame.height = current.height
        if !DisplayGeometry.isValidPlacement(frame, others: physical) {
            frame = DisplayGeometry.rightmostPlacement(
                id: virtualID, width: current.width, height: current.height, others: physical)
            target = frame
        }
        let online = Self.onlineFrames()
        var changes: [DisplayFrame] = []
        for p in physical where CGDisplayIsOnline(p.id) != 0 {
            if let now = online.first(where: { $0.id == p.id }), now.x != p.x || now.y != p.y {
                changes.append(p)
            }
        }
        if current.x != frame.x || current.y != frame.y { changes.append(frame) }
        guard !changes.isEmpty else { return }
        try apply(changes)
    }

    func makeVirtualMain(_ virtualID: CGDirectDisplayID) throws {
        if CGDisplayMirrorsDisplay(virtualID) != 0 {
            try unmirror(virtualID)
        }
        let frames = Self.onlineFrames()
        guard let shifted = DisplayGeometry.translatedSoDisplayIsAtOrigin(virtualID, frames: frames) else {
            throw ArrangementError.missingDisplay
        }
        try apply(shifted)
    }

    func mirrorMain(onto virtualID: CGDirectDisplayID) throws {
        if CGDisplayMirrorsDisplay(virtualID) != 0 {
            try unmirror(virtualID)
        }
        let main = CGMainDisplayID()
        if main == virtualID || main == 0 {
            throw ArrangementError.virtualIsMain
        }
        try transaction { config in
            CGConfigureDisplayMirrorOfDisplay(config, virtualID, main)
        }
    }

    /// Put physical displays back where they were before this virtual display
    /// was created. The virtual display is moved aside when it would cover them,
    /// then the caller releases it.
    func restore(virtualID: CGDirectDisplayID) throws {
        guard let baseline else { return }
        if virtualID != 0, CGDisplayIsOnline(virtualID) != 0, CGDisplayMirrorsDisplay(virtualID) != 0 {
            try unmirror(virtualID)
        }
        let virtual = Self.frame(for: virtualID) ?? DisplayFrame(id: virtualID, x: 0, y: 0, width: 1, height: 1)
        var plan = DisplayGeometry.restorePlan(snapshot: baseline, virtual: virtual)
        let others = baseline.filter { $0.id != virtualID }
        if var t = target, let i = plan.firstIndex(where: { $0.id == virtualID }) {
            t.width = virtual.width; t.height = virtual.height
            if !DisplayGeometry.isValidPlacement(t, others: others) {
                t = DisplayGeometry.rightmostPlacement(id: virtualID, width: virtual.width, height: virtual.height, others: others)
            }
            plan[i] = t
        }
        let applicable = plan.filter { $0.id == virtualID || CGDisplayIsOnline($0.id) != 0 }
        try apply(applicable)
    }

    func unmirror(_ display: CGDirectDisplayID) throws {
        try transaction { config in
            CGConfigureDisplayMirrorOfDisplay(config, display, kCGNullDirectDisplay)
        }
    }

    static func onlineFrames() -> [DisplayFrame] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        let error = ids.withUnsafeMutableBufferPointer { buffer in
            CGGetOnlineDisplayList(UInt32(buffer.count), buffer.baseAddress, &count)
        }
        guard error == .success else { return [] }
        return ids.prefix(Int(count)).compactMap { id in
            guard id != 0 else { return nil }
            return frame(for: id)
        }
    }

    static func frame(for id: CGDirectDisplayID) -> DisplayFrame? {
        guard id != 0 else { return nil }
        let bounds = CGDisplayBounds(id)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        return DisplayFrame(
            id: id,
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height
        )
    }

    private func apply(_ frames: [DisplayFrame]) throws {
        try transaction { config in
            for frame in frames {
                let result = CGConfigureDisplayOrigin(
                    config,
                    frame.id,
                    Int32(frame.x.rounded()),
                    Int32(frame.y.rounded())
                )
                if result != .success {
                    return result
                }
            }
            return .success
        }
    }

    private func transaction(_ body: (CGDisplayConfigRef) -> CGError) throws {
        var config: CGDisplayConfigRef?
        let began = CGBeginDisplayConfiguration(&config)
        guard began == .success, let config else {
            throw ArrangementError.beginFailed(began)
        }
        let stepped = body(config)
        if stepped != .success {
            CGCancelDisplayConfiguration(config)
            throw ArrangementError.stepFailed(stepped)
        }
        // Session scope only. Never kCGConfigurePermanently / .permanently.
        let completed = CGCompleteDisplayConfiguration(config, .forSession)
        if completed != .success {
            throw ArrangementError.stepFailed(completed)
        }
    }
}
