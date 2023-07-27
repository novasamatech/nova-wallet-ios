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
