import Foundation
import NovaCrypto

final class ValidatorPayoutInfoFactory: PayoutInfoFactoryProtocol {
    let chainAssetInfo: ChainAssetDisplayInfo

    init(chainAssetInfo: ChainAssetDisplayInfo) {
        self.chainAssetInfo = chainAssetInfo
    }

    func calculate(for accountId: AccountId, params: PayoutInfoFactoryParams) throws -> PayoutInfo? {
        let era = params.unclaimedRewards.era

        guard
            let totalRewardAmount = params.rewardDistribution.totalValidatorRewardByEra[era],
            let totalReward = Decimal.fromSubstrateAmount(
                totalRewardAmount,
                precision: chainAssetInfo.asset.assetPrecision
            ),
            let points = params.rewardDistribution.validatorPointsDistributionByEra[era] else {
            return nil
        }

        guard
            let ownStake = Decimal.fromSubstrateAmount(
                params.exposure.ownStake,
                precision: chainAssetInfo.asset.assetPrecision
            ),
            let comission = Decimal.fromSubstratePerbill(value: params.prefs.commission),
            let validatorPoints = points.individual.first(where: { $0.accountId == accountId })?.rewardPoint,
            let totalStake = Decimal.fromSubstrateAmount(
                params.exposure.totalStake,
                precision: chainAssetInfo.asset.assetPrecision
            ) else {
            return nil
        }

        let rewardFraction = points.total > 0 ? Decimal(validatorPoints) / Decimal(points.total) : 0
        let validatorTotalReward = totalReward * rewardFraction
        let ownPortion = totalStake > 0 ? ownStake / totalStake : 0
        let stakeReward = validatorTotalReward * (1 - comission) * ownPortion
        let commissionReward = validatorTotalReward * comission

        let validatorAddress = try accountId.toAddress(using: chainAssetInfo.chain)

        return PayoutInfo(
            validator: accountId,
            era: era,
            pages: params.unclaimedRewards.pages,
            reward: commissionReward + stakeReward,
            identity: params.identities[validatorAddress]
        )
    }
}
