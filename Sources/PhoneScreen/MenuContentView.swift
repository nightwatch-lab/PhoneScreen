import AppKit
#if canImport(PhoneScreenCore)
import PhoneScreenCore
#endif
import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct MenuContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAdvanced = false
    @State private var contentHeight: CGFloat = 300

    private let maxHeight: CGFloat = 640

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                if !model.apiAvailable { apiBanner }
                primaryButton
                Divider()
                presetRow
                hiDPIRow
                safeMarginRow
                Divider()
                advancedSection
                Divider()
                quitButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GeometryReader { g in
                Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
            })
        }
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        .frame(width: 400, height: min(max(contentHeight, 120), maxHeight))
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PhoneScreen").font(.headline)
            HStack(spacing: 6) {
                Circle().fill(model.isConnected ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(statusLine).font(.caption).foregroundStyle(model.isConnected ? Color.green : .secondary)
            }
            if model.bannerTone == .warning || model.bannerTone == .failure {
                Text(model.banner)
                    .font(.caption)
                    .foregroundStyle(bannerColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusLine: String {
        guard model.isConnected else { return "未连接" }
        let scale = model.settings.hiDPI ? " HiDPI" : ""
        let w = model.connectedWidth ?? model.settings.width
        let h = model.connectedHeight ?? model.settings.height
        return "已连接 · \(w)×\(h)\(scale) · \(model.role.label)"
    }

    private var apiBanner: some View {
        Text(model.apiMessage)
            .font(.caption)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var primaryButton: some View {
        Button {
            if model.isConnected {
                model.perform(.init(action: .disconnect))
            } else {
                model.commitResolution()
            }
        } label: {
            Text(model.isConnected ? "断开手机屏" : "连接手机屏")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(model.isConnected ? .red : .accentColor)
        .disabled(!model.isConnected && !model.apiAvailable)
    }

    // MARK: Main controls

    private var presetRow: some View {
        HStack {
            Text("预设")
            Spacer()
            Picker("预设", selection: presetBinding) {
                if PhonePresets.matching(width: model.settings.width, height: model.settings.height) == nil {
                    Text("自定义 \(model.settings.width)×\(model.settings.height)").tag("")
                }
                ForEach(PhonePresets.all) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }
            .labelsHidden()
            .frame(width: 230)
            .disabled(!model.apiAvailable)
            .help(currentPreset?.citation ?? "自定义分辨率")
        }
    }

    private var hiDPIRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: hiDPIBinding) {
                Text("HiDPI 清晰模式")
            }
            .toggleStyle(.switch)
            Text(hiDPIHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var safeMarginRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: Binding(get: { model.safeMarginEnabled }, set: { model.toggleSafeMargin($0) })) {
                Text("防遮挡留边")
            }
            .toggleStyle(.switch)
            Text(safeMarginHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var safeMarginHint: String {
        let w = model.settings.width, h = model.settings.height
        if SafeMargin.alreadyHasMargin(width: w, height: h) {
            return "当前预设已留边，保持 \(w)×\(h)"
        }
        let size = model.safeMarginSize
        return model.safeMarginEnabled
            ? "实际 \(size.width)×\(size.height)（原 \(w)×\(h)）"
            : "打开后为 \(size.width)×\(size.height)"
    }

    private var hiDPIHint: String {
        if model.settings.hiDPI {
            let w = model.logicalWidth ?? model.settings.width / 2
            let h = model.logicalHeight ?? model.settings.height / 2
            return "逻辑尺寸 \(w)×\(h)，字更清楚"
        }
        return "关闭后逻辑尺寸 \(model.settings.width)×\(model.settings.height)，字更小"
    }

    // MARK: Advanced

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showAdvanced.toggle() }
            } label: {
                HStack {
                    Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .frame(width: 12)
                    Text("高级").fontWeight(.semibold)
                    Spacer()
                    if !showAdvanced {
                        Text("分辨率、排列…").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showAdvanced {
                VStack(alignment: .leading, spacing: 8) {
                    resolutionGroup
                    arrangementGroup
                    windowGroup
                    safetyGroup
                }
            }
        }
    }

    private var resolutionGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            groupTitle("自定义分辨率")
            HStack(spacing: 6) {
                Text("宽")
                numberField(widthBinding, width: 64)
                Text("高")
                numberField(heightBinding, width: 64)
                Spacer()
                Button("横竖切换") { model.swapNow() }
                    .keyboardShortcut("r", modifiers: [.command, .option])
            }
            HStack {
                Text("刷新率")
                Spacer()
                Picker("刷新率", selection: refreshBinding) {
                    ForEach(DisplayLimits.refreshRates, id: \.self) { hz in
                        Text("\(hz) Hz").tag(hz)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
            }
            HStack(spacing: 6) {
                Text("PPI")
                TextField("460", value: ppiBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                    .onSubmit { model.setPPI(model.settings.ppi) }
                Spacer()
                Button("应用") { model.commitResolution() }
                    .disabled(!model.apiAvailable)
            }
            Text("PPI 只用来换算物理尺寸，不改变像素。改宽高后按回车或点应用。")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.isConnected {
                Text(connectionDetail).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var arrangementGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            groupTitle("显示排列")
            HStack {
                Button("设为主显示器") { model.makeMain() }
                    .disabled(!model.isConnected)
                Button("镜像主屏") { model.mirror() }
                    .disabled(!model.isConnected)
                Button("恢复原始排列") { model.restoreArrangement() }
                    .disabled(!model.isConnected || model.role == .extended)
            }
            .controlSize(.small)
            Text("默认放在最右边显示器的右侧，不动现有显示器。只在远控只看主屏时才设为主屏。")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var windowGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            groupTitle("窗口与启动")
            Toggle("悬浮按钮", isOn: Binding(
                get: { model.floatingButtonEnabled },
                set: { model.setFloatingButton($0) }
            ))
            .toggleStyle(.switch)
            Toggle("登录时启动", isOn: launchAtLoginBinding).toggleStyle(.switch)
        }
    }

    private var safetyGroup: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("紧急断开：\(HotkeyController.label)")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.top, 6)
            if let hotkeyError = model.hotkeyError {
                Text(hotkeyError).font(.caption2).foregroundStyle(.orange)
            }
        }
    }

    private var quitButton: some View {
        Button("退出 PhoneScreen") {
            NSApplication.shared.terminate(nil)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currentPreset: PhonePreset? {
        PhonePresets.matching(width: model.settings.width, height: model.settings.height)
    }

    private var presetBinding: Binding<String> {
        Binding(
            get: { currentPreset?.id ?? "" },
            set: { id in
                if let p = PhonePresets.all.first(where: { $0.id == id }) { model.usePreset(p) }
            }
        )
    }

    private func groupTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 6)
    }

    private func numberField(_ value: Binding<Int>, width: CGFloat) -> some View {
        TextField("", value: value, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .onSubmit { model.commitResolution() }
    }

    private var connectionDetail: String {
        var parts = ["ID \(model.displayID)"]
        if let logicalWidth = model.logicalWidth, let logicalHeight = model.logicalHeight, model.settings.hiDPI {
            parts.append("逻辑 \(logicalWidth)×\(logicalHeight)")
        }
        parts.append("\(model.settings.ppi) ppi")
        return parts.joined(separator: " · ")
    }

    private var bannerColor: Color {
        switch model.bannerTone {
        case .neutral: return .secondary
        case .success: return .primary
        case .warning: return .orange
        case .failure: return .red
        }
    }

    private var widthBinding: Binding<Int> {
        Binding(get: { model.settings.width }, set: { model.settings.width = $0 })
    }

    private var heightBinding: Binding<Int> {
        Binding(get: { model.settings.height }, set: { model.settings.height = $0 })
    }

    private var ppiBinding: Binding<Int> {
        Binding(get: { model.settings.ppi }, set: { model.settings.ppi = $0 })
    }

    private var refreshBinding: Binding<Int> {
        Binding(get: { model.settings.refreshHz }, set: { model.setRefresh($0) })
    }

    private var hiDPIBinding: Binding<Bool> {
        Binding(get: { model.settings.hiDPI }, set: { model.toggleHiDPI($0) })
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })
    }
}
