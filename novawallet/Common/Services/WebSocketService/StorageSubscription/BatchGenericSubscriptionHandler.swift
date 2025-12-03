import Foundation
import SubstrateSdk

struct BatchGenericSubscriptionChange<T: Decodable>: BatchStorageSubscriptionResult {
    let values: [String: UncertainStorage<T?>]
    let blockHash: BlockHashData?
    let context: [CodingUserInfoKey: Any]?

    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws {
        self.values = try values.reduce(into: [String: UncertainStorage<T?>]()) { accum, item in
            guard let mappingKey = item.mappingKey else {
                return
            }

            if !item.value.isNull {
                let actualValue = try item.value.map(to: T.self, with: context)
                accum[mappingKey] = .defined(actualValue)
            } else {
                accum[mappingKey] = .defined(nil)
            }
        }

        blockHash = try blockHashJson.map(to: BlockHashData?.self, with: context)
        self.context = context
    }
}

struct BatchGenericSubscriptionState<T: Decodable>: ObservableSubscriptionStateProtocol {
    typealias TChange = BatchGenericSubscriptionChange<T>

    let values: [String: T]
    let lastBlockHash: BlockHashData?
    let context: [CodingUserInfoKey: Any]?

    init(
        values: [String: T],
        lastBlockHash: BlockHashData?,
        context: [CodingUserInfoKey: Any]?
    ) {
        self.values = values
        self.lastBlockHash = lastBlockHash
        self.context = context
    }

    init(change: BatchGenericSubscriptionChange<T>) {
        values = change.values.compactMapValues { $0.valueWhenDefined(else: nil) }
        lastBlockHash = change.blockHash
        context = change.context
    }

    func merging(change: BatchGenericSubscriptionChange<T>) -> Self {
        let newValues = values.keys.reduce(
            into: [String: T]()
        ) { accum, key in
            accum[key] = change.values[key]?.valueWhenDefined(else: values[key])
        }

        return .init(
            values: newValues,
            lastBlockHash: change.blockHash,
            context: context
        )
    }
}
