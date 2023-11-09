import Foundation
import SubstrateSdk

struct BatchStorageSubscriptionRequest {
    let innerRequest: SubscriptionRequestProtocol
    let mappingKey: String?
}

struct BatchStorageSubscriptionResultValue {
    let mappingKey: String?
    let value: JSON
}

protocol BatchStorageSubscriptionResult {
    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws
}

struct BatchStorageSubscriptionRawResult: BatchStorageSubscriptionResult {
    let values: [BatchStorageSubscriptionResultValue]
    let blockHashJson: JSON

    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson: JSON,
        context _: [CodingUserInfoKey: Any]?
    ) throws {
        self.values = values
        self.blockHashJson = blockHashJson
    }
}
