import Foundation
import NovaCrypto

final class NominatorPayoutInfoFactory: PayoutInfoFactoryProtocol {
    let chainAssetInfo: ChainAssetDisplayInfo

    init(chainAssetInfo: ChainAssetDisplayInfo) {
        self.chainAssetInfo = chainAssetInfo
    }

    func calculate(for accountId: AccountId, params: PayoutInfoFactoryParams) throws -> Staking.PayoutInfo? {
        let era = params.unclaimedRewards.era
        let validatorId = params.exposure.accountId

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
            let page = params.exposure.pages.firstIndex(where: { $0.contains(where: { $0.who == accountId }) }),
            params.unclaimedRewards.pages.contains(Staking.ValidatorPage(page)),
            let nominatorStakeAmount = params.exposure.pages[page].first(where: { $0.who == accountId })?.value,
            let nominatorStake = Decimal.fromSubstrateAmount(
                nominatorStakeAmount,
                precision: chainAssetInfo.asset.assetPrecision
            ),
            let comission = Decimal.fromSubstratePerbill(value: params.prefs.commission),
            let validatorPoints = points.individual
            .first(where: { $0.accountId == validatorId })?.rewardPoint,
            let totalStake = Decimal.fromSubstrateAmount(
                params.exposure.totalStake,
                precision: chainAssetInfo.asset.assetPrecision
            ) else {
            return nil
        }

        let rewardFraction = points.total > 0 ? Decimal(validatorPoints) / Decimal(points.total) : 0
        let validatorTotalReward = totalReward * rewardFraction
        let nominatorPortion = totalStake > 0 ? nominatorStake / totalStake : 0
        let nominatorReward = validatorTotalReward * (1 - comission) * nominatorPortion

        let validatorAddress = try validatorId.toAddress(using: chainAssetInfo.chain)

        return Staking.PayoutInfo(
            validator: validatorId,
            era: era,
            pages: [Staking.ValidatorPage(page)],
            reward: nominatorReward,
            identity: params.identities[validatorAddress]
        )
    }
}
