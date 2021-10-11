import Foundation
import IrohaCrypto

final class ValidatorPayoutInfoFactory: PayoutInfoFactoryProtocol {
    let chainAssetInfo: ChainAssetDisplayInfo

    init(chainAssetInfo: ChainAssetDisplayInfo) {
        self.chainAssetInfo = chainAssetInfo
    }

    func calculate(
        for _: AccountId,
        era: EraIndex,
        validatorInfo: EraValidatorInfo,
        erasRewardDistribution: ErasRewardDistribution,
        identities: [AccountAddress: AccountIdentity]
    ) throws -> PayoutInfo? {
        guard
            let totalRewardAmount = erasRewardDistribution.totalValidatorRewardByEra[era],
            let totalReward = Decimal.fromSubstrateAmount(
                totalRewardAmount,
                precision: chainAssetInfo.asset.assetPrecision
            ),
            let points = erasRewardDistribution.validatorPointsDistributionByEra[era] else {
            return nil
        }

        guard
            let ownStake = Decimal.fromSubstrateAmount(
                validatorInfo.exposure.own,
                precision: chainAssetInfo.asset.assetPrecision
            ),
            let comission = Decimal.fromSubstratePerbill(value: validatorInfo.prefs.commission),
            let validatorPoints = points.individual
            .first(where: { $0.accountId == validatorInfo.accountId })?.rewardPoint,
            let totalStake = Decimal.fromSubstrateAmount(
                validatorInfo.exposure.total,
                precision: chainAssetInfo.asset.assetPrecision
            ) else {
            return nil
        }

        let rewardFraction = Decimal(validatorPoints) / Decimal(points.total)
        let validatorTotalReward = totalReward * rewardFraction
        let stakeReward = validatorTotalReward * (1 - comission) *
            (ownStake / totalStake)
        let commissionReward = validatorTotalReward * comission

        let validatorAddress = try validatorInfo.accountId.toAddress(using: chainAssetInfo.chain)

        return PayoutInfo(
            era: era,
            validator: validatorInfo.accountId,
            reward: commissionReward + stakeReward,
            identity: identities[validatorAddress]
        )
    }
}
