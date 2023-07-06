import Foundation
import SubstrateSdk

struct BatchStorageSubscriptionResultValue {
    let localKey: String
    let value: JSON
}

protocol BatchStorageSubscriptionResult {
    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws
}
