import Foundation
import SubstrateSdk
import BigInt

extension NominationPools {
    static func derivedAccount(for poolId: PoolId, accountType: AccountType, palletId: Data) throws -> AccountId {
        guard let prefix = "modl".data(using: .utf8) else {
            throw CommonError.dataCorruption
        }

        let scaleEncoder = ScaleEncoder()
        scaleEncoder.appendRaw(data: prefix)
        scaleEncoder.appendRaw(data: palletId)
        try accountType.rawValue.encode(scaleEncoder: scaleEncoder)
        try poolId.encode(scaleEncoder: scaleEncoder)
        scaleEncoder.appendRaw(data: Data(repeating: 0, count: SubstrateConstants.accountIdLength))

        let result = scaleEncoder.encode()

        return result.prefix(SubstrateConstants.accountIdLength)
    }

    static func pointsToBalance(for targetPoints: BigUInt, totalPoints: BigUInt, poolBalance: BigUInt) -> BigUInt {
        guard poolBalance != 0, totalPoints != 0, targetPoints != 0 else {
            return 0
        }

        return (poolBalance * targetPoints) / totalPoints
    }
}
