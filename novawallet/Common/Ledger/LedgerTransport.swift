import Foundation

protocol LedgerTransportProtocol {
    func reset()
    func prepareRequest(from message: Data, using mtu: Int) -> [Data]
    func receive(partialResponseData: Data) throws -> Data?
}

enum LedgerTransportError: Error {
    case noHeaderFound
    case noMessageSizeFound
    case unsupportedResponse(type: UInt8)
    case uncompletedResponse
    case noPartialResponse
    case overpopulated(expectedSize: UInt16, received: Data)
}

final class LedgerTransport {
    private enum Constants {
        static let dataTagId = UInt8(0x05)
        static let packetIndexLength = 2
        static let messageSizeLength = 2

        static var headerMinSize: Int { 1 + packetIndexLength }
    }

    struct Response {
        let partialData: Data
        let totalLength: UInt16

        var completed: Bool { Int(totalLength) == partialData.count }

        var overpopulated: Bool { Int(totalLength) < partialData.count }

        func byAppending(newData: Data) -> Response {
            Response(partialData: partialData + newData, totalLength: totalLength)
        }
    }

    private var partialResponse: Response?
}

extension LedgerTransport: LedgerTransportProtocol {
    func reset() {
        partialResponse = nil
    }

    func prepareRequest(from message: Data, using mtu: Int) -> [Data] {
        let totalLength = message.count
        var offest: Int = 0
        var chunks: [Data] = []

        while offest < totalLength {
            var chunk = Data()
            chunk.append(Constants.dataTagId)

            chunk.append(contentsOf: UInt16(chunks.count).bigEndianBytes)

            let isFirst = chunks.isEmpty

            if isFirst {
                chunk.append(contentsOf: UInt16(totalLength).bigEndianBytes)
            }

            let remainingPacketSize = mtu >= chunk.count ? mtu - chunk.count : 0

            if remainingPacketSize > 0 {
                let remainedMessageSize = totalLength - offest
                let packetSize = min(remainingPacketSize, remainedMessageSize)
                let packetBytes = message.subdata(in: offest ..< (offest + packetSize))
                chunk.append(contentsOf: packetBytes)

                offest += packetSize
            }

            chunks.append(chunk)
        }

        return chunks
    }

    func receive(partialResponseData: Data) throws -> Data? {
        var remainedData = partialResponseData

        guard remainedData.count >= Constants.headerMinSize else {
            throw LedgerTransportError.noHeaderFound
        }

        let tagId = remainedData[0]

        guard tagId == Constants.dataTagId else {
            throw LedgerTransportError.unsupportedResponse(type: tagId)
        }

        remainedData = remainedData.dropFirst()

        let packetIndex = UInt16(bigEndianData: remainedData.prefix(Constants.packetIndexLength))

        remainedData = remainedData.dropFirst(Constants.packetIndexLength)

        if packetIndex == 0 {
            guard partialResponse == nil else {
                throw LedgerTransportError.uncompletedResponse
            }

            guard remainedData.count >= Constants.messageSizeLength else {
                throw LedgerTransportError.noMessageSizeFound
            }

            let totalLength = UInt16(bigEndianData: remainedData.prefix(Constants.messageSizeLength))
            remainedData = remainedData.dropFirst(Constants.messageSizeLength)

            partialResponse = Response(partialData: remainedData, totalLength: totalLength)
        } else {
            partialResponse = partialResponse?.byAppending(newData: remainedData)
        }

        guard let partialResponse = partialResponse else {
            throw LedgerTransportError.noPartialResponse
        }

        if partialResponse.overpopulated {
            throw LedgerTransportError.overpopulated(
                expectedSize: partialResponse.totalLength,
                received: partialResponse.partialData
            )
        }

        if partialResponse.completed {
            let responseData = partialResponse.partialData

            self.partialResponse = nil

            return responseData
        } else {
            return nil
        }
    }
}
