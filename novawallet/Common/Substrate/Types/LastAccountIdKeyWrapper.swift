import Foundation
import SubstrateSdk

struct LastAccountIdKey: StorageKeyDecodingProtocol {
    let value: AccountId

    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
        guard let lastJson = jsonList.last else {
            throw CommonError.dataCorruption
        }

        value = try lastJson.map(to: AccountId.self, with: context)
    }
}
