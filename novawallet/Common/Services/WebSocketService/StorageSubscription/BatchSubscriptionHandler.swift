import Foundation
import SubstrateSdk

struct BatchSubscriptionHandler: JSONListConvertible {
    let blockHash: Data?

    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
        blockHash = try jsonList.last?.map(to: Data?.self, with: context)
    }
}
