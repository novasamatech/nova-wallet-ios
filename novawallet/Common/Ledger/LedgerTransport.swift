import Foundation

protocol LedgerTransportProtocol {
    func prepareRequest(from message: Data) -> [Data]
    func receive(partialResponseData: Data, for identifier: String) throws -> Data?
}

final class LedgerTransport {
    private struct Constants {
        static let dataTagId = UInt8(0x05)
    }

    private var partialResponseStorage: [String: Data] = [:]

    let mtu: Int

    init(mtu: Int = 23) {
        self.mtu = mtu
    }
}

extension LedgerTransport: LedgerTransportProtocol {
    func prepareRequest(from message: Data) -> [Data] {
        var remainingBytes = message
        var chunks: [Data] = []

        while !remainingBytes.isEmpty {
            var chunk = Data()
            chunk.append(Constants.dataTagId)

            let chunkIndexData = withUnsafeBytes(of: UInt16(chunks.count).bigEndian, Array.init)
            chunk.append(contentsOf: chunkIndexData)

            let isFirst = chunks.isEmpty

            if isFirst {
                let messageLengthData = withUnsafeBytes(of: UInt16(message.count), Array.init)
                chunk.append(contentsOf: messageLengthData)
            }

            let remainingPacketSize = mtu >= chunk.count ? mtu - chunk.count : 0

            let packetBytes = remainingBytes.prefix(remainingPacketSize)
            chunk.append(contentsOf: packetBytes)

            remainingBytes = remainingBytes.dropFirst(packetBytes.count)

            chunks.append(chunk)
        }

        return chunks
    }

    func receive(partialResponseData: Data, for identifier: String) throws -> Data? {
        nil
    }
}
