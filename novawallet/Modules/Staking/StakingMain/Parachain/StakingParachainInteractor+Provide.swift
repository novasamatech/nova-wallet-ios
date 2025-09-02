import Foundation

extension StakingParachainInteractor {
    func provideSelectedChainAsset() {
        presenter?.didReceiveChainAsset(selectedChainAsset)
    }

    func provideSelectedAccount() {
        presenter?.didReceiveAccount(selectedAccount)
    }

    func provideRewardCalculator(
        from calculatorService: CollatorStakingRewardCalculatorServiceProtocol
    ) {
        clear(cancellable: &rewardCalculatorCancellable)

        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.rewardCalculatorCancellable === operation else {
                    return
                }

                self?.rewardCalculatorCancellable = nil

                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveRewardCalculator(engine)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        rewardCalculatorCancellable = operation

        operationQueue.addOperation(operation)
    }

    func provideSelectedCollatorsInfo(
        from collatorsService: ParachainStakingCollatorServiceProtocol
    ) {
        clear(cancellable: &collatorsInfoCancellable)

        let operation = collatorsService.fetchInfoOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.collatorsInfoCancellable === operation else {
                    return
                }

                self?.collatorsInfoCancellable = nil

                do {
                    let info = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveSelectedCollators(info)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        collatorsInfoCancellable = operation

        operationQueue.addOperation(operation)
    }

    func provideNetworkInfo(
        for collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: CollatorStakingRewardCalculatorServiceProtocol
    ) {
        clear(cancellable: &networkInfoCancellable)

        let chainId = selectedChainAsset.chain.chainId

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceiveError(ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        let wrapper = networkInfoFactory.networkStakingOperation(
            for: collatorService,
            rewardCalculatorService: rewardService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.networkInfoCancellable === wrapper else {
                    return
                }

                self?.networkInfoCancellable = nil

                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveNetworkInfo(info)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        networkInfoCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func provideDurationInfo(for blockTimeService: BlockTimeEstimationServiceProtocol) {
        clear(cancellable: &durationCancellable)

        let chainId = selectedChainAsset.chain.chainId

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceiveError(ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            presenter?.didReceiveError(ChainRegistryError.connectionUnavailable)
            return
        }

        let wrapper = durationOperationFactory.createDurationOperation(
            from: runtimeService,
            connection: connection,
            blockTimeEstimationService: blockTimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.durationCancellable === wrapper else {
                    return
                }

                self?.durationCancellable = nil

                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveStakingDuration(info)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        durationCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}
