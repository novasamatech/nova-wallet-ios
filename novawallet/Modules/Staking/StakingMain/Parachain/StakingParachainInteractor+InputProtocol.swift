import Foundation
import Foundation_iOS

extension StakingParachainInteractor: StakingParachainInteractorInputProtocol {
    func setup() {
        setupSelectedAccount()
        setupSharedState()

        provideSelectedChainAsset()
        provideSelectedAccount()

        performBlockNumberSubscription()
        performRoundInfoSubscription()
        performPriceSubscription()
        performAssetBalanceSubscription()
        performDelegatorSubscription()
        performTotalRewardSubscription()
        performYieldBoostTasksSubscription()

        let collatorService = sharedState.collatorService
        let rewardCalculationService = sharedState.rewardCalculationService
        let blockTimeService = sharedState.blockTimeService

        provideRewardCalculator(from: rewardCalculationService)
        provideSelectedCollatorsInfo(from: collatorService)
        provideNetworkInfo(for: collatorService, rewardService: rewardCalculationService)
        provideDurationInfo(for: blockTimeService)

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self
    }

    func fetchDelegations(for collators: [AccountId]) {
        clear(cancellable: &delegationsCancellable)

        let collatorService = sharedState.collatorService
        let rewardService = sharedState.rewardCalculationService

        let wrapper = collatorsOperationFactory.selectedCollatorsInfoOperation(
            for: collators,
            collatorService: collatorService,
            rewardService: rewardService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.delegationsCancellable else {
                    return
                }

                self?.delegationsCancellable = nil

                do {
                    let delegations = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveDelegations(delegations)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        delegationsCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func fetchScheduledRequests() {
        clear(streamableProvider: &scheduledRequestsProvider)

        let chainId = selectedChainAsset.chain.chainId

        guard let delegatorId = selectedAccount?.chainAccount.accountId else {
            return
        }

        scheduledRequestsProvider = subscribeToScheduledRequests(for: chainId, delegatorId: delegatorId)
    }

    func update(totalRewardFilter: StakingRewardFiltersPeriod) {
        totalRewardInterval = totalRewardFilter.interval
        performTotalRewardSubscription()
    }
}

extension StakingParachainInteractor: EventVisitorProtocol {
    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        let collatorService = sharedState.collatorService
        let rewardCalculationService = sharedState.rewardCalculationService

        provideSelectedCollatorsInfo(from: collatorService)
        provideRewardCalculator(from: rewardCalculationService)
        provideNetworkInfo(for: collatorService, rewardService: rewardCalculationService)
    }

    func processBlockTimeChanged(event _: BlockTimeChanged) {
        provideDurationInfo(for: sharedState.blockTimeService)
    }
}

extension StakingParachainInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
        yieldBoostTasksProvider?.refresh()
        totalRewardProvider?.refresh()
    }
}
