import UIKit
import Operation_iOS

final class MythosCollatorInfoInteractor: CollatorStakingInfoInteractor {
    let stakingDetailsService: MythosStakingDetailsSyncServiceProtocol

    init(
        chainAsset: ChainAsset,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.stakingDetailsService = stakingDetailsService

        super.init(
            chainAsset: chainAsset,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager
        )
    }

    private func handleNew(details: MythosStakingDetails?) {
        let delegator = details.map {
            let delegations = $0.stakeDistribution.map { pair in
                StakingTarget(candidate: pair.key, amount: pair.value.stake)
            }

            return CollatorStakingDelegator(delegations: delegations)
        }

        presenter?.didReceiveDelegator(delegator)
    }

    private func subscribeDelegator() {
        stakingDetailsService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, state in
            let newDetails = state.valueWhenDefined(else: nil)
            self?.handleNew(details: newDetails)
        }
    }

    override func onSetup() {
        subscribeDelegator()
    }
}
