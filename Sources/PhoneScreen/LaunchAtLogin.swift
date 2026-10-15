import Foundation
import ServiceManagement

enum LaunchAtLoginError: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        switch self {
        case let .failed(message): return message
        }
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusText: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "登录时会打开 PhoneScreen。"
        case .requiresApproval:
            return "系统要求在「登录项」里批准 PhoneScreen。"
        case .notFound:
            return "当前不是已安装的 App。请先用 scripts/make-app.sh 打包，再从 PhoneScreen.app 启动。"
        case .notRegistered:
            return "登录时不自动打开。"
        default:
            return "登录项状态未知。"
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            throw LaunchAtLoginError.failed(
                "无法更新登录项：\(error.localizedDescription)。请确认是从 PhoneScreen.app 启动的。"
            )
        }
    }
}
