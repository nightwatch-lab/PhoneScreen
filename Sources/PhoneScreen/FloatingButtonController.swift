import AppKit
import Combine
import PhoneScreenCore

/// Small always-on-top translucent button on the virtual display that opens the PhoneScreen popover.
final class FloatingButtonController {
    static let shared = FloatingButtonController()
    private var panel: NSPanel?
    private var button: FloatingButtonView?
    private var cancellables: Set<AnyCancellable> = []
    private var screenObserver: Any?
    private let offsetKey = "floatingButtonOffset"

    func install() {
        let m = AppModel.shared
        Publishers.CombineLatest3(m.$isConnected, m.$displayID, m.$floatingButtonEnabled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                // Screen list updates slightly after connect; refresh now and shortly after.
                self?.refresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self?.refresh() }
            }
            .store(in: &cancellables)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refresh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self?.refresh() }
        }
    }

    private func screen() -> NSScreen? {
        let m = AppModel.shared
        guard m.isConnected, m.displayID != 0 else { return nil }
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return NSScreen.screens.first { ($0.deviceDescription[key] as? NSNumber)?.uint32Value == m.displayID }
    }

    func refresh() {
        guard AppModel.shared.floatingButtonEnabled, let screen = screen() else {
            panel?.orderOut(nil)
            return
        }
        let p = panel ?? makePanel()
        let vf = screen.visibleFrame
        let origin = FloatingButtonGeometry.origin(savedOffset: savedOffset(), in: vf)
        let s = FloatingButtonGeometry.size
        p.setFrame(NSRect(x: origin.x, y: origin.y, width: s, height: s), display: true)
        p.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let s = FloatingButtonGeometry.size
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: s, height: s),
                        styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isMovable = false
        p.title = "PhoneScreenFloatingButton"
        let v = FloatingButtonView(frame: NSRect(x: 0, y: 0, width: s, height: s))
        v.onClick = { [weak self] view in StatusBarController.shared.togglePopover(from: view); _ = self }
        v.onDragEnd = { [weak self] in self?.saveCurrentPosition() }
        p.contentView = v
        panel = p
        button = v
        return p
    }

    private func savedOffset() -> CGPoint? {
        guard let a = UserDefaults.standard.array(forKey: offsetKey) as? [Double], a.count == 2 else { return nil }
        return CGPoint(x: a[0], y: a[1])
    }

    private func saveCurrentPosition() {
        guard let p = panel, let screen = screen() else { return }
        let vf = screen.visibleFrame
        let clamped = FloatingButtonGeometry.clamp(p.frame.origin, in: vf)
        p.setFrameOrigin(clamped)
        let o = FloatingButtonGeometry.offset(of: clamped, in: vf)
        UserDefaults.standard.set([Double(o.x), Double(o.y)], forKey: offsetKey)
    }

    func resetPosition() {
        UserDefaults.standard.removeObject(forKey: offsetKey)
        refresh()
    }
}

final class FloatingButtonView: NSView {
    var onClick: ((NSView) -> Void)?
    var onDragEnd: (() -> Void)?
    private var hovering = false { didSet { alphaValue = hovering ? 0.9 : 0.35 } }
    private var downScreen: CGPoint = .zero
    private var downOrigin: CGPoint = .zero
    private var dragged = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        alphaValue = 0.35
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(ovalIn: r).fill()
        NSColor.white.withAlphaComponent(0.6).setStroke()
        let ring = NSBezierPath(ovalIn: r.insetBy(dx: 0.5, dy: 0.5)); ring.lineWidth = 1; ring.stroke()
        let cfg = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        if let img = NSImage(systemSymbolName: "iphone", accessibilityDescription: "PhoneScreen")?
            .withSymbolConfiguration(cfg) {
            let tinted = NSImage(size: img.size, flipped: false) { rect in
                img.draw(in: rect); NSColor.white.set(); rect.fill(using: .sourceAtop); return true
            }
            let s = tinted.size
            tinted.draw(in: NSRect(x: bounds.midX - s.width / 2, y: bounds.midY - s.height / 2, width: s.width, height: s.height))
        }
    }

    // Only the circle is hit-testable; corners pass through.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let p = convert(point, from: superview)
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        return hypot(p.x - c.x, p.y - c.y) <= bounds.width / 2 ? self : nil
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }

    override func mouseDown(with event: NSEvent) {
        downScreen = NSEvent.mouseLocation
        downOrigin = window?.frame.origin ?? .zero
        dragged = false
        hovering = true
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation
        if !dragged && FloatingButtonGeometry.isClick(from: downScreen, to: now) { return }
        dragged = true
        window?.setFrameOrigin(CGPoint(x: downOrigin.x + now.x - downScreen.x, y: downOrigin.y + now.y - downScreen.y))
    }

    override func mouseUp(with event: NSEvent) {
        if dragged { onDragEnd?() } else { onClick?(self) }
        dragged = false
    }
}
