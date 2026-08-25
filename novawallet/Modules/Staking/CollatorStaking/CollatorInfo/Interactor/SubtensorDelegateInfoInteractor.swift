import UIKit
import Operation_iOS

final class SubtensorDelegateInfoInteractor: CollatorStakingInfoInteractor {
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol

    init(
        chainAsset: ChainAsset,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.positionsSyncService = positionsSyncService

        super.init(
            chainAsset: chainAsset,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager
        )
    }

    deinit {
        positionsSyncService.remove(observer: self)
    }

    private func handleNew(state: Multistaking.SubtensorStakingState?) {
        let delegator = state.map { stakingState in
            let delegations = stakingState.positions
                .filter { $0.netuid == SubtensorStakingPallet.rootNetuid }
                .map { StakingTarget(candidate: $0.hotkey, amount: $0.stakeAlpha) }

            return CollatorStakingDelegator(delegations: delegations)
        }

        presenter?.didReceiveDelegator(delegator)
    }

    private func subscribeDelegator() {
        positionsSyncService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.handleNew(state: newState)
        }
    }

    override func onSetup() {
        subscribeDelegator()
    }
}
