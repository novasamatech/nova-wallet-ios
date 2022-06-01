import Foundation
import SoraFoundation

extension StakingParachainInteractor: StakingParachainInteractorInputProtocol {
    func setup() {
        createInitialServices()
        continueSetup()
    }

    func fetchDelegations(for collators: [AccountId]) {
        clear(cancellable: &delegationsCancellable)

        guard
            let chain = selectedChainAsset?.chain,
            let connection = chainRegistry.getConnection(for: chain.chainId) else {
            presenter?.didReceiveError(ChainRegistryError.connectionUnavailable)
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            presenter?.didReceiveError(ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        guard
            let collatorService = sharedState.collatorService,
            let rewardService = sharedState.rewardCalculationService else {
            presenter?.didReceiveError(CommonError.dataCorruption)
            return
        }

        let wrapper = collatorsOperationFactory.selectedCollatorsInfoOperation(
            for: collators,
            collatorService: collatorService,
            rewardService: rewardService,
            connection: connection,
            runtimeProvider: runtimeService,
            chainFormat: chain.chainFormat
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

    func fetchScheduledRequests(for collators: [AccountId]) {
        clear(cancellable: &scheduledRequestsCancellable)

        guard
            let chainId = selectedChainAsset?.chain.chainId,
            let connection = chainRegistry.getConnection(for: chainId) else {
            presenter?.didReceiveError(ChainRegistryError.connectionUnavailable)
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceiveError(ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        guard let delegator = selectedAccount?.chainAccount.accountId else {
            presenter?.didReceiveScheduledRequests(nil)
            return
        }

        let wrapper = scheduledRequestsFactory.createOperation(
            for: delegator,
            collators: collators,
            runtimeService: runtimeService,
            connection: connection
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.scheduledRequestsCancellable else {
                    return
                }

                self?.scheduledRequestsCancellable = nil

                do {
                    let requests = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveScheduledRequests(requests)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        scheduledRequestsCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension StakingParachainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        updateAfterSelectedAccountChange()
    }

    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        guard
            let collatorService = sharedState.collatorService,
            let rewardCalculationService = sharedState.rewardCalculationService else {
            return
        }

        provideSelectedCollatorsInfo(from: collatorService)
        provideRewardCalculator(from: rewardCalculationService)
        provideNetworkInfo(for: collatorService, rewardService: rewardCalculationService)
    }

    func processBlockTimeChanged(event _: BlockTimeChanged) {
        guard let blockTimeService = sharedState.blockTimeService else {
            return
        }

        provideDurationInfo(for: blockTimeService)
    }
}

extension StakingParachainInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
    }
}
