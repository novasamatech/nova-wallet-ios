import Foundation

struct PagedKeysRequest: Encodable {
    let key: String
    let count: UInt32?
    let offset: String?
    let blockHash: Data?

    init(key: String, count: UInt32? = 1000, offset: String? = nil, blockHash: Data? = nil) {
        self.key = key
        self.count = count
        self.offset = offset
        self.blockHash = blockHash
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(key)

        if let count = count {
            try container.encode(count)
        }

        if let offset = offset {
            try container.encode(offset)
        }

        if let blockHash = blockHash {
            try container.encode(blockHash.toHex(includePrefix: true))
        }
    }
}
