import Foundation

/// A display rectangle in global display points, before it is handed to
/// CGConfigureDisplayOrigin. Pure geometry so arrangement math can be tested
/// without CoreGraphics.
public struct DisplayFrame: Equatable, Codable {
    public var id: UInt32
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(id: UInt32, x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
}

public enum DisplayGeometry {
    /// True when the rectangles share a positive area. Edge contact is not overlap.
    public static func overlaps(_ a: DisplayFrame, _ b: DisplayFrame) -> Bool {
        a.x < b.maxX && a.maxX > b.x && a.y < b.maxY && a.maxY > b.y
    }

    /// Shift every frame by the same delta so `id` sits at (0, 0).
    /// The display at the global origin is the main display.
    public static func translatedSoDisplayIsAtOrigin(
        _ id: UInt32,
        frames: [DisplayFrame]
    ) -> [DisplayFrame]? {
        guard let target = frames.first(where: { $0.id == id }) else { return nil }
        let dx = -target.x
        let dy = -target.y
        return frames.map { frame in
            var copy = frame
            copy.x += dx
            copy.y += dy
            return copy
        }
    }

    /// Move `frame` to the right of `others` so a restore can put the real
    /// displays back without sharing an origin with the virtual display.
    public static func parked(
        _ frame: DisplayFrame,
        avoiding others: [DisplayFrame],
        gap: Double = 100
    ) -> DisplayFrame {
        var parked = frame
        let right = others.map(\.maxX).max() ?? 0
        parked.x = right + gap
        parked.y = 0
        if others.contains(where: { overlaps($0, parked) }) {
            let bottom = others.map(\.maxY).max() ?? 0
            parked.x = 0
            parked.y = bottom + gap
        }
        return parked
    }

    /// Origins to apply while the virtual display still exists.
    /// Snapshot frames are restored. The virtual display is appended, parked
    /// only when it would cover a restored display.
    public static func restorePlan(
        snapshot: [DisplayFrame],
        virtual: DisplayFrame
    ) -> [DisplayFrame] {
        var virtualFrame = virtual
        if snapshot.contains(where: { overlaps($0, virtualFrame) }) {
            virtualFrame = parked(virtualFrame, avoiding: snapshot)
        }
        return snapshot + [virtualFrame]
    }

    /// Default spot for a new virtual display: flush to the right edge of the
    /// rightmost existing display, top-aligned with it. Existing displays are
    /// never moved.
    public static func rightmostPlacement(
        id: UInt32,
        width: Double,
        height: Double,
        others: [DisplayFrame]
    ) -> DisplayFrame {
        guard let anchor = others.max(by: { a, b in
            a.maxX == b.maxX ? a.y > b.y : a.maxX < b.maxX
        }) else {
            return DisplayFrame(id: id, x: 0, y: 0, width: width, height: height)
        }
        return DisplayFrame(id: id, x: anchor.maxX, y: anchor.y, width: width, height: height)
    }

    /// True when the frame touches at least one other display along an edge
    /// (with some shared span) and overlaps none of them.
    public static func isValidPlacement(_ frame: DisplayFrame, others: [DisplayFrame]) -> Bool {
        guard !others.isEmpty else { return true }
        if others.contains(where: { overlaps($0, frame) }) { return false }
        return others.contains { o in
            let vertical = (frame.x == o.maxX || frame.maxX == o.x) && frame.y < o.maxY && frame.maxY > o.y
            let horizontal = (frame.y == o.maxY || frame.maxY == o.y) && frame.x < o.maxX && frame.maxX > o.x
            return vertical || horizontal
        }
    }

    /// Saved origin if it is still a valid placement, otherwise rightmost.
    public static func placement(
        id: UInt32,
        width: Double,
        height: Double,
        others: [DisplayFrame],
        saved: (x: Double, y: Double)?
    ) -> DisplayFrame {
        if let saved {
            let candidate = DisplayFrame(id: id, x: saved.x, y: saved.y, width: width, height: height)
            if isValidPlacement(candidate, others: others) { return candidate }
        }
        return rightmostPlacement(id: id, width: width, height: height, others: others)
    }
}
