import Foundation
import SubstrateSdk

struct BatchSubscriptionHandler: BatchStorageSubscriptionResult {
    let blockHash: Data?

    init(
        values _: [BatchStorageSubscriptionResultValue],
        blockHashJson: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws {
        blockHash = try blockHashJson.map(to: Data?.self, with: context)
    }
}
