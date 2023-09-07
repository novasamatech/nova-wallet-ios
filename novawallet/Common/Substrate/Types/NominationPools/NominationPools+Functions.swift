import Foundation
import SubstrateSdk
import BigInt

extension NominationPools {
    static func derivedAccountPrefix(for palletId: Data) throws -> Data {
        guard let prefix = "modl".data(using: .utf8) else {
            throw CommonError.dataCorruption
        }

        let scaleEncoder = ScaleEncoder()
        scaleEncoder.appendRaw(data: prefix)
        scaleEncoder.appendRaw(data: palletId)

        return scaleEncoder.encode()
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

    static func balanceToPoints(
        for targetBalance: BigUInt,
        totalPoints: BigUInt,
        poolBalance: BigUInt,
        roundingUp: Bool
    ) -> BigUInt {
        guard poolBalance != 0, totalPoints != 0, targetBalance != 0 else {
            return 0
        }

        let multBalancePoints = targetBalance * totalPoints
        let (quotient, reminder) = multBalancePoints.quotientAndRemainder(dividingBy: poolBalance)

        if roundingUp, reminder > 0 {
            return quotient + 1
        } else {
            return quotient
        }
    }

    static func unstakingBalanceToPoints(
        for targetBalance: BigUInt,
        totalPoints: BigUInt,
        poolBalance: BigUInt,
        memberStakedPoints: BigUInt
    ) -> BigUInt {
        let unstakingPoints = balanceToPoints(
            for: targetBalance,
            totalPoints: totalPoints,
            poolBalance: poolBalance,
            roundingUp: true
        )

        return min(unstakingPoints, memberStakedPoints)
    }
}
