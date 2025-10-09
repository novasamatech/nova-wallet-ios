import Foundation
import SubstrateSdk

struct EraStakersRemoteKey: JSONListConvertible {
    let era: Staking.EraIndex
    let validator: AccountId

    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
        guard jsonList.count == 2 else {
            throw CommonError.dataCorruption
        }

        era = try jsonList[0].map(to: StringScaleMapper.self, with: context).value
        validator = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
    }
}
