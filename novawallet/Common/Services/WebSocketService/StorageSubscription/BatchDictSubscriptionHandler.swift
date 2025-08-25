import Foundation
import SubstrateSdk

struct BatchDictSubscriptionChange: BatchStorageSubscriptionResult {
    let values: [String: JSON]
    let blockHash: BlockHashData?
    let context: [CodingUserInfoKey: Any]?

    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws {
        self.values = values.reduce(into: [String: JSON]()) {
            if let mappingKey = $1.mappingKey {
                $0[mappingKey] = $1.value
            }
        }

        blockHash = try blockHashJson.map(to: BlockHashData?.self, with: context)
        self.context = context
    }
}

struct BatchDictSubscriptionState: ObservableSubscriptionStateProtocol {
    typealias TChange = BatchDictSubscriptionChange

    let values: [String: JSON]
    let lastBlockHash: BlockHashData?
    let context: [CodingUserInfoKey: Any]?

    init(
        values: [String: JSON],
        lastBlockHash: BlockHashData?,
        context: [CodingUserInfoKey: Any]?
    ) {
        self.values = values
        self.lastBlockHash = lastBlockHash
        self.context = context
    }

    init(change: BatchDictSubscriptionChange) {
        values = change.values
        lastBlockHash = change.blockHash
        context = change.context
    }

    func merging(change: BatchDictSubscriptionChange) -> Self {
        let newValues = values.keys.reduce(
            into: [String: JSON]()
        ) { accum, key in
            accum[key] = change.values[key] ?? values[key]
        }

        return .init(
            values: newValues,
            lastBlockHash: change.blockHash,
            context: context
        )
    }

    func decode<T: Decodable>(for key: String) throws -> T? {
        guard let json = values[key] else {
            return nil
        }

        return try json.map(to: T?.self, with: context)
    }
}
