import CoreGraphics

/// Placement math for the floating button. Rects use bottom-left origin (AppKit).
/// Saved positions are offsets of the button's origin relative to the display's visibleFrame origin.
public enum FloatingButtonGeometry {
    public static let size: CGFloat = 44
    public static let inset: CGFloat = 12

    public static func defaultOrigin(in visible: CGRect) -> CGPoint {
        clamp(CGPoint(x: visible.maxX - size - inset, y: visible.maxY - size - inset), in: visible)
    }

    public static func clamp(_ origin: CGPoint, in visible: CGRect) -> CGPoint {
        let maxX = max(visible.minX, visible.maxX - size)
        let maxY = max(visible.minY, visible.maxY - size)
        return CGPoint(x: min(max(origin.x, visible.minX), maxX),
                       y: min(max(origin.y, visible.minY), maxY))
    }

    public static func origin(savedOffset: CGPoint?, in visible: CGRect) -> CGPoint {
        guard let o = savedOffset else { return defaultOrigin(in: visible) }
        return clamp(CGPoint(x: visible.minX + o.x, y: visible.minY + o.y), in: visible)
    }

    public static func offset(of origin: CGPoint, in visible: CGRect) -> CGPoint {
        let c = clamp(origin, in: visible)
        return CGPoint(x: c.x - visible.minX, y: c.y - visible.minY)
    }

    /// A press counts as a click if the pointer moved less than this.
    public static let dragThreshold: CGFloat = 4
    public static func isClick(from a: CGPoint, to b: CGPoint) -> Bool {
        hypot(b.x - a.x, b.y - a.y) < dragThreshold
    }
}
