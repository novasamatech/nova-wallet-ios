import Foundation
import BigInt

final class HybridStakingRecommendationMediator: BaseStakingRecommendationMediator {
    let directStakingMediator: RelaychainStakingRecommendationMediating
    let nominationPoolsMediator: RelaychainStakingRecommendationMediating
    let directStakingRestrictionsBuilder: DirectStakingRestrictionsBuilder

    private var restrictions: RelaychainStakingRestrictions?

    init(
        directStakingMediator: RelaychainStakingRecommendationMediating,
        nominationPoolsMediator: RelaychainStakingRecommendationMediating,
        directStakingRestrictionsBuilder: DirectStakingRestrictionsBuilder
    ) {
        self.directStakingMediator = directStakingMediator
        self.nominationPoolsMediator = nominationPoolsMediator
        self.directStakingRestrictionsBuilder = directStakingRestrictionsBuilder
    }

    override func updateRecommendation(for amount: BigUInt) {
        guard let restrictions = restrictions else {
            return
        }

        if let minStake = restrictions.minRewardableStake, amount < minStake {
            directStakingMediator.delegate = nil
            nominationPoolsMediator.delegate = self

            nominationPoolsMediator.update(amount: amount)
        } else {
            directStakingMediator.delegate = self
            nominationPoolsMediator.delegate = nil

            directStakingMediator.update(amount: amount)
        }
    }

    override func performSetup() {
        directStakingMediator.startRecommending()
        nominationPoolsMediator.startRecommending()

        directStakingRestrictionsBuilder.delegate = self
        directStakingRestrictionsBuilder.start()
    }

    override func clearState() {
        super.clearState()

        directStakingMediator.delegate = nil
        directStakingMediator.stopRecommending()

        nominationPoolsMediator.delegate = nil
        nominationPoolsMediator.stopRecommending()

        directStakingRestrictionsBuilder.delegate = nil
        directStakingRestrictionsBuilder.stop()
    }
}

extension HybridStakingRecommendationMediator: RelaychainStakingRestrictionsBuilderDelegate {
    func restrictionsBuilder(
        _: RelaychainStakingRestrictionsBuilding,
        didPrepare restrictions: RelaychainStakingRestrictions
    ) {
        self.restrictions = restrictions

        isReady = true
        updateRecommendationIfReady()
    }

    func restrictionsBuilder(_: RelaychainStakingRestrictionsBuilding, didReceive error: Error) {
        delegate?.didReceiveRecommendation(error: error)
    }
}

extension HybridStakingRecommendationMediator: RelaychainStakingRecommendationDelegate {
    func didReceive(recommendation: RelaychainStakingRecommendation, amount: BigUInt) {
        delegate?.didReceive(recommendation: recommendation, amount: amount)
    }

    func didReceiveRecommendation(error: Error) {
        delegate?.didReceiveRecommendation(error: error)
    }
}
