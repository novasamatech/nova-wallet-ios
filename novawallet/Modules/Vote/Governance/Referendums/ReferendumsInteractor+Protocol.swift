import Foundation
import RobinHood
import SoraFoundation

extension ReferendumsInteractor: ReferendumsInteractorInputProtocol {
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

extension ReferendumsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil, let chain = governanceState.settings.value?.chain {
            subscribeToAssetPrice(for: chain)
        }
    }
}
