import Foundation
import Foundation_iOS

extension StakingRelaychainInteractor: StakingRelaychainInteractorInputProtocol {
    func setup() {
        do {
            setupSelectedAccountAndChainAsset()

            try sharedState.setup(for: selectedAccount?.accountId)

            provideNewChain()
            provideSelectedAccount()

            guard
                let chainId = selectedChainAsset?.chain.chainId,
                let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                return
            }

            let eraValidatorService = sharedState.eraValidatorService
            let rewardCalculationService = sharedState.rewardCalculatorService

            provideMaxNominatorsPerValidator(from: runtimeService)

            performPriceSubscription()
            performAccountInfoSubscription()
            performStashControllerSubscription()
            performNominatorLimitsSubscription()
            performBagListParamsSubscription()

            provideRewardCalculator(from: rewardCalculationService)
            provideEraStakersInfo(from: eraValidatorService)

            provideNetworkStakingInfo()

            eventCenter.add(observer: self, dispatchIn: .main)

            applicationHandler.delegate = self
        } catch {
            logger?.error("Can't setup state: \(error)")
        }
    }

    func update(totalRewardFilter: StakingRewardFiltersPeriod) {
        totalRewardInterval = totalRewardFilter.interval
        performTotalRewardSubscription()
    }
}

extension StakingRelaychainInteractor: EventVisitorProtocol {
    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        let eraValidatorService = sharedState.eraValidatorService
        let rewardCalculationService = sharedState.rewardCalculatorService

        provideNetworkStakingInfo()
        provideEraStakersInfo(from: eraValidatorService)
        provideRewardCalculator(from: rewardCalculationService)
    }

    func processBlockTimeChanged(event _: BlockTimeChanged) {
        provideNetworkStakingInfo()
    }
}

extension StakingRelaychainInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
        totalRewardProvider?.refresh()
    }
}
