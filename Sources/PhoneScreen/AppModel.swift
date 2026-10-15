import AppKit
import Darwin
import Foundation
import VirtualDisplaySPI
#if canImport(PhoneScreenCore)
import PhoneScreenCore
#endif

enum DisplayRole: String {
    case extended
    case main
    case mirror

    var label: String {
        switch self {
        case .extended: return "扩展显示器"
        case .main: return "主显示器"
        case .mirror: return "镜像主屏幕"
        }
    }
}

enum BannerTone {
    case neutral
    case success
    case warning
    case failure
}

final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var settings: AppSettings = .iPhone17eDefault
    /// 防遮挡留边. Stored separately so state.json stays compatible.
    @Published var safeMarginEnabled: Bool = UserDefaults.standard.bool(forKey: "safeMarginEnabled")
    /// Actual pixel size of the live virtual display (after 防遮挡留边).
    @Published var connectedWidth: Int?
    @Published var connectedHeight: Int?

    var safeMarginSize: (width: Int, height: Int) {
        SafeMargin.apply(width: settings.width, height: settings.height, enabled: true)
    }
    @Published var isConnected = false
    @Published var role: DisplayRole = .extended
    @Published var displayID: UInt32 = 0
    @Published var logicalWidth: Int?
    @Published var logicalHeight: Int?
    @Published var roundedToEven = false
    @Published var banner = "选择预设或填入像素宽高，然后连接。"
    @Published var bannerTone: BannerTone = .neutral
    @Published var apiAvailable = false
    @Published var apiMessage = "正在检查虚拟显示器接口。"
    @Published var launchAtLogin = false
    @Published var hotkeyError: String?
    @Published var stateWarning: String?
    @Published var floatingButtonEnabled = UserDefaults.standard.object(forKey: "floatingButtonEnabled") as? Bool ?? true

    private let session = VirtualDisplaySession()
    private let arrangement = DisplayArrangement()
    private let hotkeys = HotkeyController()
    private let control = ControlServer()
    private let store: StateStore
    private var signalSources: [DispatchSourceSignal] = []
    private var started = false
    private var loaded = false
    private var connectInProgress = false
    private var pendingURLs: [URL] = []
    private var applyingLiveChange = false

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        store = StateStore(fileURL: PhoneScreenPaths.stateFileURL(home: home))
    }

    func start() {
        dispatchOnMain {
            guard !self.started else { return }
            self.started = true
            signal(SIGPIPE, SIG_IGN)
            self.loadState()
            self.refreshAPI()
            self.refreshLaunchAtLogin()
            self.installSignals()
            self.hotkeys.onFire = { [weak self] in
                self?.emergencyDisconnect()
            }
            self.hotkeys.register()
            self.hotkeyError = self.hotkeys.lastError
            do {
                try self.control.start { [weak self] command in
                    guard let self else {
                        return CommandResult(ok: false, message: "应用已退出。", connected: false, apiAvailable: false)
                    }
                    return self.perform(command)
                }
            } catch ControlServerError.alreadyRunning {
                NSApp.terminate(nil)
                return
            } catch {
                self.banner = error.localizedDescription
                self.bannerTone = .failure
            }
            let queued = self.pendingURLs
            self.pendingURLs.removeAll()
            for url in queued {
                self.handle(url: url)
            }
        }
    }

    func handle(url: URL) {
        dispatchOnMain {
            guard self.started else {
                self.pendingURLs.append(url)
                return
            }
            switch CommandParser.parseURL(url) {
            case let .failure(error):
                self.setBanner(error.message, tone: .failure)
            case let .success(command):
                _ = self.perform(command)
            }
        }
    }

    @discardableResult
    func perform(_ command: RemoteCommand) -> CommandResult {
        if !Thread.isMainThread {
            return DispatchQueue.main.sync { self.perform(command) }
        }
        switch command.action {
        case .connect:
            do {
                settings = try command.settings(applyingTo: settings)
                try connectThrowing(preservingRole: true)
                saveState()
                return result(ok: true, message: successMessage())
            } catch {
                setBanner(error.localizedDescription, tone: .failure)
                return result(ok: false, message: error.localizedDescription)
            }
        case .disconnect:
            let wasConnected = isConnected
            disconnect()
            let message = wasConnected ? "已断开虚拟显示器，并恢复原来的排列。" : "当前没有虚拟显示器。"
            setBanner(message, tone: .neutral)
            return result(ok: true, message: message)
        case .swap:
            settings.swapOrientation()
            saveState()
            if isConnected {
                connect(preservingRole: true)
            } else {
                setBanner("已对调为 \(settings.width)×\(settings.height)。连接后生效。", tone: .success)
            }
            return result(ok: bannerTone != .failure, message: banner)
        case .main:
            guard isConnected else {
                let message = "还没有虚拟显示器，无法设为主屏。"
                setBanner(message, tone: .warning)
                return result(ok: false, message: message)
            }
            do {
                try arrangement.makeVirtualMain(session.displayID)
                role = .main
                setBanner("虚拟屏已是主显示器。只采集主屏的远控现在会看到它。", tone: .success)
                return result(ok: true, message: banner)
            } catch {
                setBanner(error.localizedDescription, tone: .failure)
                return result(ok: false, message: error.localizedDescription)
            }
        case .mirror:
            guard isConnected else {
                let message = "还没有虚拟显示器，无法镜像。"
                setBanner(message, tone: .warning)
                return result(ok: false, message: message)
            }
            do {
                if role == .main {
                    try arrangement.restore(virtualID: session.displayID)
                    role = .extended
                }
                try arrangement.mirrorMain(onto: session.displayID)
                role = .mirror
                setBanner("虚拟屏正在镜像当前主屏幕。", tone: .success)
                return result(ok: true, message: banner)
            } catch {
                setBanner(error.localizedDescription, tone: .failure)
                return result(ok: false, message: error.localizedDescription)
            }
        case .restore:
            guard isConnected else {
                let message = "还没有虚拟显示器。"
                setBanner(message, tone: .warning)
                return result(ok: false, message: message)
            }
            do {
                try arrangement.restore(virtualID: session.displayID)
                role = .extended
                setBanner("已恢复连接虚拟屏之前的排列。", tone: .success)
                return result(ok: true, message: banner)
            } catch {
                setBanner(error.localizedDescription, tone: .failure)
                return result(ok: false, message: error.localizedDescription)
            }
        case .status:
            return result(ok: true, message: isConnected ? "已连接 \(settings.width)×\(settings.height)。" : "未连接。")
        }
    }

    /// Last origin of the virtual display in extend mode (user may drag it in
    /// System Settings). Reused only while still adjacent and non-overlapping.
    var savedVirtualOrigin: (x: Double, y: Double)? {
        get {
            let d = UserDefaults.standard
            guard let x = d.object(forKey: "virtualOriginX") as? Double,
                  let y = d.object(forKey: "virtualOriginY") as? Double else { return nil }
            return (x, y)
        }
        set {
            let d = UserDefaults.standard
            if let newValue {
                d.set(newValue.x, forKey: "virtualOriginX")
                d.set(newValue.y, forKey: "virtualOriginY")
            } else {
                d.removeObject(forKey: "virtualOriginX")
                d.removeObject(forKey: "virtualOriginY")
            }
        }
    }

    func usePreset(_ preset: PhonePreset) {
        settings.applyPreset(preset)
        saveState()
        connect(preservingRole: true)
    }

    func commitResolution() {
        saveState()
        connect(preservingRole: true)
    }

    func toggleHiDPI(_ enabled: Bool) {
        guard !applyingLiveChange else { return }
        settings.hiDPI = enabled
        saveState()
        scheduleModeSwitch()
    }

    func toggleSafeMargin(_ enabled: Bool) {
        guard !applyingLiveChange else { return }
        safeMarginEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "safeMarginEnabled")
        scheduleModeSwitch()
    }

    func setRefresh(_ hz: Int) {
        guard !applyingLiveChange else { return }
        settings.refreshHz = hz
        saveState()
        reapplyIfConnected()
    }

    func setPPI(_ ppi: Int) {
        settings.ppi = ppi
        saveState()
        reapplyIfConnected()
    }

    func swapNow() {
        _ = perform(.init(action: .swap))
    }

    func disconnect() {
        dispatchOnMain {
            self.saveState()
            if self.session.isConnected {
                if self.role == .extended, let f = DisplayArrangement.frame(for: self.session.displayID) {
                    self.savedVirtualOrigin = (f.x, f.y)
                }
                try? self.arrangement.restore(virtualID: self.session.displayID)
                self.session.disconnect()
            }
            self.arrangement.clearBaseline()
            self.role = .extended
            self.isConnected = false
            self.displayID = 0
            self.logicalWidth = nil
            self.logicalHeight = nil
            self.roundedToEven = false
        }
    }

    func emergencyDisconnect() {
        disconnect()
        setBanner("已用紧急热键断开虚拟显示器。", tone: .warning)
    }

    func restoreArrangement() {
        _ = perform(.init(action: .restore))
    }

    func makeMain() {
        _ = perform(.init(action: .main))
    }

    func mirror() {
        _ = perform(.init(action: .mirror))
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<String, Error> = Result {
                try LaunchAtLogin.setEnabled(enabled)
                return LaunchAtLogin.statusText
            }
            let now = LaunchAtLogin.isEnabled
            DispatchQueue.main.async {
                self.launchAtLogin = now
                switch result {
                case let .success(text):
                    self.setBanner(text, tone: enabled ? .success : .neutral)
                case let .failure(error):
                    self.setBanner(error.localizedDescription, tone: .failure)
                }
            }
        }
    }

    func setFloatingButton(_ enabled: Bool) {
        floatingButtonEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "floatingButtonEnabled")
    }

    /// Queries SMAppService off the main thread (only at launch and after toggling).
    func refreshLaunchAtLogin() {
        DispatchQueue.global(qos: .utility).async {
            let enabled = LaunchAtLogin.isEnabled
            DispatchQueue.main.async { self.launchAtLogin = enabled }
        }
    }

    private func connect(preservingRole: Bool) {
        do {
            try connectThrowing(preservingRole: preservingRole)
        } catch {
            setBanner(error.localizedDescription, tone: .failure)
        }
    }

    private func connectThrowing(preservingRole: Bool) throws {
        if connectInProgress {
            throw SessionError(message: "正在连接，请稍候。")
        }
        connectInProgress = true
        defer { connectInProgress = false }
        let previous = preservingRole ? role : .extended
        if session.isConnected {
            disconnect()
        }
        refreshAPI()
        guard apiAvailable else {
            throw SessionError(message: apiMessage)
        }
        var effective = settings
        let margined = SafeMargin.apply(width: settings.width, height: settings.height, enabled: safeMarginEnabled)
        effective.width = margined.width
        effective.height = margined.height
        let usesMargin = margined.width != settings.width || margined.height != settings.height
        let plan = try effective.plan()
        if !usesMargin {
            applyingLiveChange = true
            settings.width = plan.pixelWidth
            settings.height = plan.pixelHeight
            applyingLiveChange = false
        }
        connectedWidth = plan.pixelWidth
        connectedHeight = plan.pixelHeight
        roundedToEven = plan.roundedToEven
        arrangement.captureBaseline()
        do {
            // Register full + 留边 sizes in 1× and HiDPI so later toggles switch in place.
            let modeSet = try? VirtualModeSet.make(width: settings.width, height: settings.height, refreshHz: settings.refreshHz, ppi: settings.ppi)
            try session.connect(plan, modeSet: modeSet)
        } catch {
            arrangement.clearBaseline()
            throw error
        }
        isConnected = true
        displayID = session.displayID
        session.onModeApplied = { [weak self] id in
            guard let self, self.role == .extended, self.session.displayID == id else { return }
            try? self.arrangement.assertPlacement(id)
        }
        try? arrangement.placeVirtual(session.displayID, saved: savedVirtualOrigin)
        logicalWidth = plan.logicalWidth
        logicalHeight = plan.logicalHeight
        role = .extended
        if previous == .main {
            try arrangement.makeVirtualMain(session.displayID)
            role = .main
        } else if previous == .mirror {
            try arrangement.mirrorMain(onto: session.displayID)
            role = .mirror
        }
        saveState()
        setBanner(successMessage(), tone: .success)
    }

    private var modeSwitchWork: DispatchWorkItem?

    /// Debounced HiDPI / 留边 change: switch mode in place, recreate only if needed.
    private func scheduleModeSwitch() {
        guard isConnected, !applyingLiveChange else { return }
        modeSwitchWork?.cancel()
        StatusBarController.shared.beginModeSwitch()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.modeSwitchWork = nil
            self.applyModeSwitch()
            StatusBarController.shared.endModeSwitch()
        }
        modeSwitchWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func applyModeSwitch() {
        guard isConnected else { return }
        var effective = settings
        let margined = SafeMargin.apply(width: settings.width, height: settings.height, enabled: safeMarginEnabled)
        effective.width = margined.width
        effective.height = margined.height
        guard let plan = try? effective.plan() else {
            connect(preservingRole: true)
            return
        }
        if session.switchInPlace(to: plan) {
            connectedWidth = plan.pixelWidth
            connectedHeight = plan.pixelHeight
            roundedToEven = plan.roundedToEven
            logicalWidth = plan.logicalWidth
            logicalHeight = plan.logicalHeight
            if role == .extended { try? arrangement.assertPlacement(session.displayID) }
            saveState()
            setBanner(successMessage(), tone: .success)
        } else {
            connect(preservingRole: true)
        }
    }

    private func reapplyIfConnected() {
        guard isConnected, !applyingLiveChange else { return }
        connect(preservingRole: true)
    }

    private func successMessage() -> String {
        var text = "已连接 \(connectedWidth ?? settings.width)×\(connectedHeight ?? settings.height)"
        if settings.hiDPI, let logicalWidth, let logicalHeight {
            text += "（逻辑 \(logicalWidth)×\(logicalHeight)，HiDPI 2×）"
        }
        text += " @ \(settings.refreshHz) Hz，\(role.label)。"
        if roundedToEven {
            text += " 奇数边已加 1，凑成偶数像素。"
        }
        return text
    }

    private func result(ok: Bool, message: String) -> CommandResult {
        CommandResult(
            ok: ok,
            message: message,
            connected: isConnected,
            width: isConnected ? settings.width : settings.width,
            height: settings.height,
            logicalWidth: logicalWidth,
            logicalHeight: logicalHeight,
            hiDPI: settings.hiDPI,
            hz: settings.refreshHz,
            ppi: settings.ppi,
            displayID: isConnected ? displayID : nil,
            role: isConnected ? role.rawValue : nil,
            apiAvailable: apiAvailable,
            roundedToEven: roundedToEven
        )
    }

    private func refreshAPI() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion < 14 {
            apiAvailable = false
            apiMessage = "需要 macOS 14 或更新的系统。当前是 \(version.majorVersion).\(version.minorVersion)。"
            return
        }
        if PhoneScreenVirtualDisplayAPIAvailable() {
            apiAvailable = true
            apiMessage = "CGVirtualDisplay 可用。"
        } else {
            apiAvailable = false
            apiMessage = "当前系统没有 CGVirtualDisplay 私有接口，不能创建虚拟显示器。"
        }
    }

    private func loadState() {
        let loaded = store.load()
        settings = loaded.state.settings
        stateWarning = loaded.warning
        if let stateWarning {
            banner = stateWarning
            bannerTone = .warning
        }
        self.loaded = true
    }

    private func saveState() {
        guard loaded else { return }
        let state = PhoneScreenState(settings: settings)
        try? store.save(state)
    }

    private func installSignals() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                self?.disconnect()
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private func setBanner(_ text: String, tone: BannerTone) {
        dispatchOnMain {
            self.banner = text
            self.bannerTone = tone
        }
    }

    private func dispatchOnMain(_ body: @escaping () -> Void) {
        if Thread.isMainThread {
            body()
        } else {
            DispatchQueue.main.async(execute: body)
        }
    }
}
