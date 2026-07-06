import Foundation
import Network
import TelegramCore

// One end-to-end SOCKS5 health probe, built on Network.framework so it works pre-authorization
// without Telegram's own network stack. Success = TCP connect to the proxy + username/password
// SOCKS5 auth + CONNECT to a Telegram data-center, all within `timeout`. That predicts a working
// MTProto-over-SOCKS5 connection, because MTProto dials the very same DC host:port.
final class FenixuzSocks5Probe {
    // Telegram DC2 (the default DC). If the proxy can open a tunnel here, it can carry Telegram
    // traffic.
    private static let telegramProbeHost: [UInt8] = [149, 154, 167, 51]
    private static let telegramProbePort: UInt16 = 443

    let server: ProxyServerSettings
    private let username: String
    private let password: String
    private let timeout: TimeInterval
    private let connection: NWConnection
    private let queue: DispatchQueue

    private var finished = false
    private var completion: ((Bool) -> Void)?

    init?(server: ProxyServerSettings, timeout: TimeInterval) {
        guard case let .socks5(username, password) = server.connection else {
            return nil
        }
        guard server.port > 0, server.port <= 65535, let port = NWEndpoint.Port(rawValue: UInt16(server.port)) else {
            return nil
        }
        self.server = server
        self.username = username ?? ""
        self.password = password ?? ""
        self.timeout = timeout
        self.connection = NWConnection(host: NWEndpoint.Host(server.host), port: port, using: .tcp)
        self.queue = DispatchQueue(label: "uz.fenixuz.app.AutoProxy.probe")
    }

    deinit {
        self.connection.cancel()
    }

    // `completion` is delivered on this probe's private serial queue.
    func start(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        self.queue.asyncAfter(deadline: .now() + self.timeout) { [weak self] in
            self?.finish(false)
        }
        self.connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else {
                return
            }
            switch state {
            case .ready:
                self.sendGreeting()
            case .failed, .cancelled:
                self.finish(false)
            default:
                break
            }
        }
        self.connection.start(queue: self.queue)
    }

    // MARK: - SOCKS5 handshake

    private func sendGreeting() {
        // VER = 5, NMETHODS = 1, METHOD = 0x02 (username/password).
        self.send([0x05, 0x01, 0x02]) { [weak self] ok in
            guard let self = self else {
                return
            }
            guard ok else {
                self.finish(false)
                return
            }
            self.receive(count: 2) { [weak self] data in
                guard let self = self else {
                    return
                }
                guard let data = data, data.count == 2, data[0] == 0x05, data[1] == 0x02 else {
                    self.finish(false)
                    return
                }
                self.sendAuth()
            }
        }
    }

    private func sendAuth() {
        let user = Array(self.username.utf8)
        let pass = Array(self.password.utf8)
        guard user.count <= 255, pass.count <= 255 else {
            self.finish(false)
            return
        }
        // VER = 1, ULEN, UNAME, PLEN, PASSWD.
        var payload: [UInt8] = [0x01, UInt8(user.count)]
        payload.append(contentsOf: user)
        payload.append(UInt8(pass.count))
        payload.append(contentsOf: pass)
        self.send(payload) { [weak self] ok in
            guard let self = self else {
                return
            }
            guard ok else {
                self.finish(false)
                return
            }
            self.receive(count: 2) { [weak self] data in
                guard let self = self else {
                    return
                }
                guard let data = data, data.count == 2, data[0] == 0x01, data[1] == 0x00 else {
                    self.finish(false)
                    return
                }
                self.sendConnect()
            }
        }
    }

    private func sendConnect() {
        // VER = 5, CMD = CONNECT (1), RSV = 0, ATYP = IPv4 (1), ADDR (4), PORT (2).
        var payload: [UInt8] = [0x05, 0x01, 0x00, 0x01]
        payload.append(contentsOf: FenixuzSocks5Probe.telegramProbeHost)
        payload.append(UInt8(FenixuzSocks5Probe.telegramProbePort >> 8))
        payload.append(UInt8(FenixuzSocks5Probe.telegramProbePort & 0xff))
        self.send(payload) { [weak self] ok in
            guard let self = self else {
                return
            }
            guard ok else {
                self.finish(false)
                return
            }
            // Reply: VER, REP, ... — REP == 0x00 means the tunnel to Telegram is open.
            self.receive(count: 2) { [weak self] data in
                guard let self = self else {
                    return
                }
                guard let data = data, data.count == 2, data[0] == 0x05, data[1] == 0x00 else {
                    self.finish(false)
                    return
                }
                self.finish(true)
            }
        }
    }

    // MARK: - Low-level IO (all on self.queue)

    private func send(_ bytes: [UInt8], completion: @escaping (Bool) -> Void) {
        self.connection.send(content: Data(bytes), completion: .contentProcessed { error in
            completion(error == nil)
        })
    }

    private func receive(count: Int, completion: @escaping (Data?) -> Void) {
        self.connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
            if error != nil {
                completion(nil)
            } else if let data = data, data.count == count {
                completion(data)
            } else {
                completion(nil)
            }
        }
    }

    private func finish(_ success: Bool) {
        if self.finished {
            return
        }
        self.finished = true
        self.connection.cancel()
        let completion = self.completion
        self.completion = nil
        completion?(success)
    }
}
