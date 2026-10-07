import Foundation

struct ExtrinsicStatusUpdate {
    let extrinsicHash: String
    let extrinsicStatus: ExtrinsicStatus

    func getInBlockOrFinalizedHash() -> BlockHash? {
        switch extrinsicStatus {
        case let .inBlock(blockHash):
            blockHash
        case let .finalized(blockHash):
            blockHash
        default:
            nil
        }
    }

    func getTerminalBlockHash(trackingTill: ExtrinsicTrackingTill) -> BlockHash? {
        switch (trackingTill, extrinsicStatus) {
        case let (.finalized, .finalized(blockHash)):
            blockHash
        case let (.inBlock, .inBlock(blockHash)),
             let (.inBlock, .finalized(blockHash)):
            blockHash
        default:
            nil
        }
    }

    func getFinalExtrinsicFailure() -> FinalExtrinsicStatusError? {
        switch extrinsicStatus {
        case .invalid:
            .invalid
        case .dropped:
            .dropped
        case .usurped:
            .usurped
        case .finalityTimeout:
            .finalityTimeout
        default:
            nil
        }
    }
}

enum ExtrinsicStatus: Decodable, Equatable {
    case future
    case ready
    case broadcast([String])
    case inBlock(String)
    case retracted(String)
    case finalityTimeout(String)
    case finalized(String)
    case usurped(String)
    case dropped
    case invalid
    case other

    private enum PlainStatus: String {
        case future
        case ready
        case dropped
        case invalid
    }

    private enum CodingKeys: String, CodingKey {
        case broadcast
        case inBlock
        case retracted
        case finalityTimeout
        case finalized
        case usurped
    }

    init(from decoder: Decoder) throws {
        if let plainStatus = try? decoder.singleValueContainer().decode(String.self) {
            self.init(plainStatus: plainStatus)
        } else {
            try self.init(keyedStatusFrom: decoder)
        }
    }

    private init(plainStatus: String) {
        self = switch PlainStatus(rawValue: plainStatus) {
        case .future:
            .future
        case .ready:
            .ready
        case .dropped:
            .dropped
        case .invalid:
            .invalid
        case nil:
            .other
        }
    }

    private init(keyedStatusFrom decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        switch values.allKeys.first {
        case .broadcast:
            self = try .broadcast(values.decode([String].self, forKey: .broadcast))
        case .inBlock:
            self = try .inBlock(values.decode(String.self, forKey: .inBlock))
        case .retracted:
            self = try .retracted(values.decode(String.self, forKey: .retracted))
        case .finalityTimeout:
            self = try .finalityTimeout(values.decode(String.self, forKey: .finalityTimeout))
        case .finalized:
            self = try .finalized(values.decode(String.self, forKey: .finalized))
        case .usurped:
            self = try .usurped(values.decode(String.self, forKey: .usurped))
        case nil:
            self = .other
        }
    }
}

enum FinalExtrinsicStatusError: Error {
    case finalityTimeout
    case invalid
    case dropped
    case usurped
}
