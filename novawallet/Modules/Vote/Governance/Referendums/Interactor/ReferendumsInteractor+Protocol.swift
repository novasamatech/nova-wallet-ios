import Foundation
import Operation_iOS
import Foundation_iOS

extension ReferendumsInteractor: ReferendumsInteractorInputProtocol {
    func setup() {
        setupState { [weak self] _ in
            self?.continueSetup()
        }
    }

    func remakeSubscriptions() {
        clear()

        if let option = governanceState.settings.value {
            let chain = option.chain
            let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest())

            setup(with: accountResponse?.accountId, option: option)
        }
    }

    func saveSelected(option: GovernanceSelectedOption) {
        if option != governanceState.settings.value {
            clear()

            governanceState.settings.save(value: option, runningCompletionIn: .main) { [weak self] result in
                switch result {
                case let .success(option):
                    self?.handleOptionChange(for: option)
                case let .failure(error):
                    self?.presenter?.didReceiveError(.chainSaveFailed(error))
                }
            }
        }
    }

    func becomeOnline() {
        if let chain = governanceState.settings.value?.chain {
            subscribeToBlockNumber(for: chain)
        }

        if governanceState.settings.value != nil {
            metadataProvider?.refresh()
        }
    }

    func putOffline() {
        clearBlockNumberSubscription()
    }

    func refreshReferendums() {
        if governanceState.settings.value != nil {
            provideReferendumsIfNeeded()
            provideBlockTime()

            provideOffchainVotingIfNeeded()
        }
    }

    func refreshUnlockSchedule(for tracksVoting: ReferendumTracksVotingDistribution, blockHash: Data?) {
        if let chain = governanceState.settings.value?.chain {
            clear(cancellable: &unlockScheduleCancellable)

            guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
                presenter?.didReceiveError(.unlockScheduleFetchFailed(ChainRegistryError.connectionUnavailable))
                return
            }

            guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
                presenter?.didReceiveError(.unlockScheduleFetchFailed(ChainRegistryError.runtimeMetadaUnavailable))
                return
            }

            guard let lockStateFactory = governanceState.locksOperationFactory else {
                presenter?.didReceiveUnlockSchedule(.init(items: []))
                return
            }

            let wrapper = lockStateFactory.buildUnlockScheduleWrapper(
                for: tracksVoting,
                from: connection,
                runtimeProvider: runtimeProvider,
                blockHash: blockHash
            )

            wrapper.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    guard self?.unlockScheduleCancellable === wrapper else {
                        return
                    }

                    self?.unlockScheduleCancellable = nil

                    do {
                        let schedule = try wrapper.targetOperation.extractNoCancellableResultData()
                        self?.presenter?.didReceiveUnlockSchedule(schedule)
                    } catch {
                        self?.presenter?.didReceiveError(.unlockScheduleFetchFailed(error))
                    }
                }
            }

            unlockScheduleCancellable = wrapper

            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        }
    }

    func retryBlockTime() {
        provideBlockTime()
    }

    func retryOffchainVotingFetch() {
        provideOffchainVotingIfNeeded()
    }
}

extension ReferendumsInteractor: GovMetadataLocalStorageSubscriber, GovMetadataLocalStorageHandler {
    var govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol {
        governanceState.govMetadataLocalSubscriptionFactory
    }

    func handleGovernanceMetadataPreview(
        result: Result<[DataProviderChange<ReferendumMetadataLocal>], Error>,
        option: GovernanceSelectedOption
    ) {
        guard let currentOption = governanceState.settings.value, currentOption == option else {
            return
        }

        switch result {
        case let .success(changes):
            presenter?.didReceiveReferendumsMetadata(changes)
        case let .failure(error):
            presenter?.didReceiveError(.metadataSubscriptionFailed(error))
        }
    }
}

extension ReferendumsInteractor: WalletLocalSubscriptionHandler, WalletLocalStorageSubscriber {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            presenter?.didReceiveError(.balanceSubscriptionFailed(error))
        }
    }
}

extension ReferendumsInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            presenter?.didReceivePrice(price)
        case let .failure(error):
            presenter?.didReceiveError(.priceSubscriptionFailed(error))
        }
    }
}

extension ReferendumsInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId: ChainModel.Id) {
        guard timelineChainId == chainId else {
            return
        }

        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                presenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockNumberSubscriptionFailed(error))
        }
    }
}

extension ReferendumsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil, let chain = governanceState.settings.value?.chain {
            subscribeToAssetPrice(for: chain)
        }
    }
}

extension ReferendumsInteractor: Localizable {
    func applyLocalization() {
        if presenter != nil, let option = governanceState.settings.value {
            setupSwipeGovService(for: option)
        }
    }
}

extension ReferendumsInteractor: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        clearCancellable()
        governanceState.subscriptionFactory?.cancelCancellable()
    }
}
