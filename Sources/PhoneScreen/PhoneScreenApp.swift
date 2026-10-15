import AppKit
import Carbon
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel.shared
        StatusBarController.shared.install()
        FloatingButtonController.shared.install()
        model.start()
        if let url = LaunchHandoff.url {
            LaunchHandoff.url = nil
            model.handle(url: url)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppModel.shared.disconnect()
        return .terminateNow
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let raw = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: raw) else { return }
        AppModel.shared.handle(url: url)
    }
}

enum PhoneScreenApp {
    static let delegate = AppDelegate()
    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

final class StatusBarController: NSObject {
    static let shared = StatusBarController()
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private var cancellable: Any?

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "iphone", accessibilityDescription: "PhoneScreen")
        item.button?.target = self
        item.button?.action = #selector(toggle(_:))
        self.item = item
        popover.behavior = .transient
        let host = NSHostingController(
            rootView: MenuContentView().environmentObject(AppModel.shared)
        )
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        cancellable = AppModel.shared.$isConnected.sink { [weak self] on in
            DispatchQueue.main.async {
                self?.item?.button?.image = NSImage(
                    systemSymbolName: on ? "iphone.radiowaves.left.and.right" : "iphone",
                    accessibilityDescription: "PhoneScreen")
            }
        }
    }

    @objc private func toggle(_ sender: NSStatusBarButton) {
        togglePopover(from: sender)
    }

    /// Shows/hides the shared popover anchored to `view` (status item or floating button).
    func togglePopover(from view: NSView) {
        if popover.isShown {
            let sameAnchor = popover.contentViewController?.view.window != nil && lastAnchor === view
            popover.performClose(view)
            if sameAnchor { return }
        }
        lastAnchor = view
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    private weak var lastAnchor: NSView?
    private var switchDepth = 0
    private var restoreWork: DispatchWorkItem?

    /// Keep the popover open and anchored while the display mode changes.
    func beginModeSwitch() {
        switchDepth += 1
        restoreWork?.cancel()
        popover.behavior = .applicationDefined
    }

    func endModeSwitch() {
        switchDepth = max(0, switchDepth - 1)
        guard switchDepth == 0 else { return }
        // Screen parameters settle shortly after the mode change; then move the
        // floating button and re-anchor the popover without closing it.
        for delay in [0.15, 0.7] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                FloatingButtonController.shared.refresh()
                self?.repositionPopover()
            }
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.switchDepth == 0 else { return }
            self.popover.behavior = .transient
        }
        restoreWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func repositionPopover() {
        guard popover.isShown else { return }
        if let anchor = lastAnchor, anchor.window?.isVisible == true {
            popover.positioningRect = anchor.bounds
        } else if let button = item?.button {
            // Floating button gone (e.g. display recreated): hop to the status item.
            lastAnchor = button
            popover.performClose(nil)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
