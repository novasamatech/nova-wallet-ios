import Foundation
import SubstrateSdk

struct LastAccountIdKey: StorageKeyDecodingProtocol {
    let value: AccountId

    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
        guard let lastJson = jsonList.last else {
            throw CommonError.dataCorruption
        }

        if let rawValue = try? lastJson.map(to: AccountId.self, with: context) {
            value = rawValue
        } else {
            value = try lastJson.map(to: BytesCodable.self, with: context).wrappedValue
        }
    }
}
