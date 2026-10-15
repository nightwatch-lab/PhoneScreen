import Foundation

/// "防遮挡留边": shortens the long edge to 80% (rounded to an even number) so
/// a remote-view app that letterboxes the picture leaves blank bands where the
/// phone's camera and on-screen toolbars sit. The short edge is untouched.
public enum SafeMargin {
    public static let factor = 0.8

    public static func roundToEven(_ value: Double) -> Int {
        Int((value / 2).rounded()) * 2
    }

    /// Presets that already carry their own margin are left alone.
    public static func alreadyHasMargin(width: Int, height: Int) -> Bool {
        let p = PhonePresets.iPhone17eUUSafe
        return (width == p.width && height == p.height) || (width == p.height && height == p.width)
    }

    public static func apply(width: Int, height: Int, enabled: Bool) -> (width: Int, height: Int) {
        guard enabled, !alreadyHasMargin(width: width, height: height) else { return (width, height) }
        if height >= width {
            return (width, roundToEven(Double(height) * factor))
        }
        return (roundToEven(Double(width) * factor), height)
    }
}
