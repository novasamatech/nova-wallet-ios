import Foundation
import SubstrateSdk

struct EraStakersPagedRemoteKey: JSONListConvertible {
    let era: Staking.EraIndex
    let validator: AccountId
    let page: UInt32

    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
        guard jsonList.count == 3 else {
            throw CommonError.dataCorruption
        }

        era = try jsonList[0].map(to: StringScaleMapper.self, with: context).value
        validator = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
        page = try jsonList[2].map(to: StringScaleMapper.self, with: context).value
    }
}
