import Foundation
import Network
import MTProtoEngineFFI

@available(macOS 10.14, iOS 12.0, *)
final class RustStreamHost {
    private let engine: OpaquePointer
    private let queue = DispatchQueue(label: "org.telegram.MTProtoRust.streams")
    private var connections: [UInt64: NWConnection] = [:]
    private var paused = Set<UInt64>()

    init(engine: OpaquePointer) {
        self.engine = engine
    }

    func open(stream: UInt64, host: String, port: UInt16, serverName: String?, alpn: [String]) {
        self.queue.async {
            guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                self.report(stream: stream, error: "bad port \(port)")
                return
            }
            let tcp = NWProtocolTCP.Options()
            tcp.noDelay = true
            tcp.connectionTimeout = 15
            let parameters: NWParameters
            if let serverName = serverName {
                let tls = NWProtocolTLS.Options()
                sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, serverName)
                for name in alpn {
                    sec_protocol_options_add_tls_application_protocol(tls.securityProtocolOptions, name)
                }
                sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, _, complete in
                    complete(true)
                }, self.queue)
                parameters = NWParameters(tls: tls, tcp: tcp)
            } else {
                parameters = NWParameters(tls: nil, tcp: tcp)
            }
            let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: parameters)
            self.connections[stream] = connection
            connection.stateUpdateHandler = { [weak self] state in
                self?.stateChanged(stream: stream, connection: connection, state: state)
            }
            connection.start(queue: self.queue)
        }
    }

    func write(stream: UInt64, data: Data) {
        self.queue.async {
            guard let connection = self.connections[stream] else {
                return
            }
            let count = data.count
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                guard let self = self, self.connections[stream] === connection else {
                    return
                }
                if let error = error {
                    self.fail(stream: stream, error: "\(error)")
                } else {
                    mt_stream_sent(self.engine, stream, count)
                }
            })
        }
    }

    func close(stream: UInt64) {
        self.queue.async {
            self.paused.remove(stream)
            self.connections.removeValue(forKey: stream)?.cancel()
        }
    }

    func resume(stream: UInt64) {
        self.queue.async {
            if self.paused.remove(stream) != nil, let connection = self.connections[stream] {
                self.receive(stream: stream, connection: connection)
            }
        }
    }

    private func stateChanged(stream: UInt64, connection: NWConnection, state: NWConnection.State) {
        guard self.connections[stream] === connection else {
            return
        }
        switch state {
        case .ready:
            mt_stream_opened(self.engine, stream)
            self.receive(stream: stream, connection: connection)
        case let .waiting(error), let .failed(error):
            self.fail(stream: stream, error: "\(error)")
        default:
            break
        }
    }

    private func receive(stream: UInt64, connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self, self.connections[stream] === connection else {
                return
            }
            var more = true
            if let data = data, !data.isEmpty {
                more = data.withUnsafeBytes { bytes -> Bool in
                    return mt_stream_received(self.engine, stream, MTBytes(data: bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), length: bytes.count)) != 0
                }
            }
            if let error = error {
                self.fail(stream: stream, error: "\(error)")
            } else if isComplete {
                self.connections.removeValue(forKey: stream)?.cancel()
                self.paused.remove(stream)
                self.report(stream: stream, error: nil)
            } else if more {
                self.receive(stream: stream, connection: connection)
            } else {
                self.paused.insert(stream)
            }
        }
    }

    private func fail(stream: UInt64, error: String) {
        self.connections.removeValue(forKey: stream)?.cancel()
        self.paused.remove(stream)
        self.report(stream: stream, error: error)
    }

    private func report(stream: UInt64, error: String?) {
        let text = error ?? ""
        text.withCString { pointer in
            mt_stream_closed(self.engine, stream, MTString(data: pointer, length: strlen(pointer)))
        }
    }
}

func rustStreamHostCallbacks() -> MTStreamHost {
    return MTStreamHost(
        open: { context, stream, target in
            guard let context = context, let target = target else {
                return
            }
            let runtime = Unmanaged<RustEngineRuntime>.fromOpaque(context).takeUnretainedValue()
            let alpn = rustEngineString(target.pointee.alpn).split(separator: ",").map(String.init)
            runtime.openStream(stream, host: rustEngineString(target.pointee.host), port: target.pointee.port, serverName: target.pointee.tls != 0 ? rustEngineString(target.pointee.server_name) : nil, alpn: alpn, carrier: target.pointee.carrier != 0)
        },
        write: { context, stream, bytes in
            guard let context = context, let data = bytes.data, bytes.length > 0 else {
                return
            }
            let runtime = Unmanaged<RustEngineRuntime>.fromOpaque(context).takeUnretainedValue()
            runtime.writeStream(stream, data: Data(bytes: data, count: bytes.length))
        },
        close: { context, stream in
            guard let context = context else {
                return
            }
            Unmanaged<RustEngineRuntime>.fromOpaque(context).takeUnretainedValue().closeStream(stream)
        },
        resume: { context, stream in
            guard let context = context else {
                return
            }
            Unmanaged<RustEngineRuntime>.fromOpaque(context).takeUnretainedValue().resumeStream(stream)
        }
    )
}
