import Foundation

enum ExtrinsicStatus: Decodable {
    case inBlock(String)
    case finalized(String)
    case finalityTimeout(String)
    case other

    private enum CodingKeys: String, CodingKey {
        case broadcast
        case inBlock
        case finalized
        case finalityTimeout
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? values.decode(String.self, forKey: .inBlock) {
            self = .inBlock(value)
        } else if let value = try? values.decode(String.self, forKey: .finalized) {
            self = .finalized(value)
        } else if let value = try? values.decode(String.self, forKey: .finalityTimeout) {
            self = .finalityTimeout(value)
        } else {
            self = .other
        }
    }
}
