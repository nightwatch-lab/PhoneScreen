import Darwin
import Foundation
#if canImport(PhoneScreenCore)
import PhoneScreenCore
#endif

enum ControlServerError: Error, LocalizedError {
    case alreadyRunning
    case socketFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "PhoneScreen 已经在运行。"
        case let .socketFailed(message):
            return message
        }
    }
}

final class ControlServer {
    private var listenFD: Int32 = -1
    private let queue = DispatchQueue(label: "com.phonescreen.control")
    private var handler: ((RemoteCommand) -> CommandResult)?

    static func canConnect(path: String) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        guard var addr = unixAddress(path) else { return false }
        return withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sock in
                Darwin.connect(fd, sock, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
            }
        }
    }

    func start(handler: @escaping (RemoteCommand) -> CommandResult) throws {
        let path = PhoneScreenPaths.socketPath(uid: getuid())
        if Self.canConnect(path: path) {
            throw ControlServerError.alreadyRunning
        }
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw ControlServerError.socketFailed("socket() 失败")
        }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        guard var addr = Self.unixAddress(path) else {
            close(fd)
            throw ControlServerError.socketFailed("套接字路径过长")
        }
        let bound = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sock in
                bind(fd, sock, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else {
            let message = String(cString: strerror(errno))
            close(fd)
            throw ControlServerError.socketFailed("bind 失败：\(message)")
        }
        guard listen(fd, 4) == 0 else {
            close(fd)
            throw ControlServerError.socketFailed("listen 失败")
        }
        chmod(path, 0o600)
        listenFD = fd
        self.handler = handler
        queue.async { [weak self] in
            self?.acceptLoop()
        }
    }

    private func acceptLoop() {
        while listenFD >= 0 {
            let client = accept(listenFD, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                break
            }
            var yes: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
            handle(client)
            close(client)
        }
    }

    private func handle(_ client: Int32) {
        let data = Self.readLine(from: client, limit: 65_536)
        let result: CommandResult
        if let data, let command = try? JSONDecoder().decode(RemoteCommand.self, from: data), let handler {
            result = handler(command)
        } else {
            result = CommandResult(ok: false, message: "无法解析命令。", connected: false, apiAvailable: false)
        }
        guard let encoded = try? JSONEncoder().encode(result) else { return }
        try? Self.writeAll(encoded, to: client)
        var newline: UInt8 = 10
        _ = Darwin.write(client, &newline, 1)
    }

    static func exchange(_ command: RemoteCommand, path: String) throws -> CommandResult {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ControlServerError.socketFailed("socket() 失败") }
        defer { close(fd) }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        guard var addr = unixAddress(path) else {
            throw ControlServerError.socketFailed("套接字路径过长")
        }
        let connected = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sock in
                Darwin.connect(fd, sock, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            throw ControlServerError.socketFailed("连接 PhoneScreen 失败")
        }
        let payload = try JSONEncoder().encode(command)
        var bytes = [UInt8](payload)
        bytes.append(10)
        try writeAll(Data(bytes), to: fd)
        guard let response = readLine(from: fd, limit: 65_536) else {
            throw ControlServerError.socketFailed("没有收到回应")
        }
        return try JSONDecoder().decode(CommandResult.self, from: response)
    }

    private static func unixAddress(_ path: String) -> sockaddr_un? {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = path.utf8CString
        guard bytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &addr.sun_path) { buffer in
            for (offset, byte) in bytes.enumerated() {
                buffer[offset] = UInt8(bitPattern: byte)
            }
        }
        return addr
    }

    private static func readLine(from fd: Int32, limit: Int) -> Data? {
        var buffer: [UInt8] = []
        buffer.reserveCapacity(256)
        var byte: UInt8 = 0
        while buffer.count < limit {
            let count = Darwin.read(fd, &byte, 1)
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                return nil
            }
            if byte == 10 { break }
            buffer.append(byte)
        }
        guard !buffer.isEmpty else { return nil }
        return Data(buffer)
    }

    @discardableResult
    private static func writeAll(_ data: Data, to fd: Int32) throws -> Void {
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var sent = 0
            while sent < raw.count {
                let wrote = Darwin.write(fd, base.advanced(by: sent), raw.count - sent)
                if wrote < 0 {
                    if errno == EINTR { continue }
                    throw ControlServerError.socketFailed("写入命令失败")
                }
                sent += wrote
            }
        }
    }
}
