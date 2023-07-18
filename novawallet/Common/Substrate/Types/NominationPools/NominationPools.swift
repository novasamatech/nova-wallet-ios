import Foundation
import SubstrateSdk
import BigInt

enum NominationPools {
    typealias PoolId = UInt32

    struct PoolMember: Decodable {
        @StringCodable var poolId: PoolId
        @StringCodable var points: BigUInt
        @StringCodable var lastRecordedRewardCounter: BigUInt
        let unbondingEras: [SupportPallet.KeyValue<StringScaleMapper<EraIndex>, StringScaleMapper<BigUInt>>]
    }

    enum AccountType: UInt8 {
        case bonded
        case reward
    }

    static func derivedAccount(for poolId: PoolId, accountType: AccountType, palletId: Data) throws -> AccountId {
        guard let prefix = "modl".data(using: .utf8) else {
            throw CommonError.dataCorruption
        }

        let scaleEncoder = ScaleEncoder()
        scaleEncoder.appendRaw(data: prefix)
        scaleEncoder.appendRaw(data: palletId)
        try accountType.rawValue.encode(scaleEncoder: scaleEncoder)
        try poolId.encode(scaleEncoder: scaleEncoder)
        try scaleEncoder.appendRaw(data: Data(repeating: 0, count: SubstrateConstants.accountIdLength))

        let result = scaleEncoder.encode()

        return result.prefix(SubstrateConstants.accountIdLength)
    }
}
