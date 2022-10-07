import Foundation
import RobinHood
import SubstrateSdk

final class ReferendumsInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: ReferendumsInteractorOutputProtocol?

    let selectedMetaAccount: MetaAccountModel
    let governanceState: GovernanceSharedState
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let referendumsOperationFactory: ReferendumsOperationFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let operationQueue: OperationQueue

    var govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol {
        governanceState.govMetadataLocalSubscriptionFactory
    }

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?
    private var blockNumberSubscription: CallbackStorageSubscription<StringScaleMapper<BlockNumber>>?
    private var metadataProvider: AnySingleValueProvider<ReferendumMetadataMapping>?

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    private var referendumsCancellable: CancellableCall?
    private var votesCancellable: CancellableCall?

    init(
        selectedMetaAccount: MetaAccountModel,
        governanceState: GovernanceSharedState,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        referendumsOperationFactory: ReferendumsOperationFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.governanceState = governanceState
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.referendumsOperationFactory = referendumsOperationFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    private func clear() {
        clear(streamableProvider: &assetBalanceProvider)
        clear(singleValueProvider: &priceProvider)
        clear(singleValueProvider: &metadataProvider)

        blockNumberSubscription = nil

        clearCancellable()
    }

    private func clearCancellable() {
        clear(cancellable: &referendumsCancellable)
    }

    private func continueSetup() {
        guard let chain = governanceState.settings.value else {
            presenter?.didReceiveError(.settingsLoadFailed)
            return
        }

        let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest())

        setup(with: accountResponse?.accountId, chain: chain)
    }

    private func setup(with accountId: AccountId?, chain: ChainModel) {
        presenter?.didReceiveSelectedChain(chain)

        if let accountId = accountId {
            subscribeToAssetBalance(for: accountId, chain: chain)
        } else {
            presenter?.didReceiveAssetBalance(nil)
        }

        subscribeToAssetPrice(for: chain)

        subscribeToBlockNumber(for: chain)
        subscribeToMetadata(for: chain)
    }

    private func subscribeToBlockNumber(for chain: ChainModel) {
        guard blockNumberSubscription == nil else {
            return
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            presenter?.didReceiveError(.blockNumberSubscriptionFailed(ChainRegistryError.connectionUnavailable))
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            presenter?.didReceiveError(.blockNumberSubscriptionFailed(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        do {
            let localKey = try localKeyFactory.createFromStoragePath(.blockNumber, chainId: chain.chainId)
            let request = UnkeyedSubscriptionRequest(storagePath: .blockNumber, localKey: localKey)
            blockNumberSubscription = CallbackStorageSubscription(
                request: request,
                connection: connection,
                runtimeService: runtimeProvider,
                repository: nil,
                operationQueue: operationQueue,
                callbackQueue: .main
            ) { [weak self] result in
                switch result {
                case let .success(resultData):
                    if let blockNumber = resultData?.value {
                        self?.presenter?.didReceiveBlockNumber(blockNumber)
                    }
                case let .failure(error):
                    self?.presenter?.didReceiveError(.blockNumberSubscriptionFailed(error))
                }
            }
        } catch {
            presenter?.didReceiveError(.blockNumberSubscriptionFailed(error))
        }
    }

    private func subscribeToAssetBalance(for accountId: AccountId, chain: ChainModel) {
        guard let asset = chain.utilityAsset() else {
            return
        }

        assetBalanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    private func subscribeToAssetPrice(for chain: ChainModel) {
        guard let priceId = chain.utilityAsset()?.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func subscribeToMetadata(for chain: ChainModel) {
        metadataProvider = subscribeGovMetadata(for: chain)
    }

    private func handleChainChange(for newChain: ChainModel) {
        clear()

        let accountResponse = selectedMetaAccount.fetch(for: newChain.accountRequest())

        setup(with: accountResponse?.accountId, chain: newChain)
    }

    private func provideReferendumsIfNeeded() {
        guard referendumsCancellable == nil else {
            return
        }

        guard let chain = governanceState.settings.value else {
            presenter?.didReceiveError(.referendumsFetchFailed(PersistentValueSettingsError.missingValue))
            return
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            presenter?.didReceiveError(.referendumsFetchFailed(ChainRegistryError.connectionUnavailable))
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            presenter?.didReceiveError(.referendumsFetchFailed(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        let wrapper = referendumsOperationFactory.fetchAllReferendumsWrapper(
            from: connection,
            runtimeProvider: runtimeProvider
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.referendumsCancellable else {
                    return
                }

                self?.referendumsCancellable = nil

                do {
                    let referendums = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveReferendums(referendums)
                } catch {
                    self?.presenter?.didReceiveError(.referendumsFetchFailed(error))
                }
            }
        }

        referendumsCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func provideVotesIfNeeded() {
        guard votesCancellable == nil else {
            return
        }

        guard let chain = governanceState.settings.value else {
            presenter?.didReceiveError(.votesFetchFailed(PersistentValueSettingsError.missingValue))
            return
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            presenter?.didReceiveError(.votesFetchFailed(ChainRegistryError.connectionUnavailable))
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            presenter?.didReceiveError(.votesFetchFailed(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            presenter?.didReceiveVotes([:])
            return
        }

        let wrapper = referendumsOperationFactory.fetchAccountVotes(
            for: accountId,
            from: connection,
            runtimeProvider: runtimeProvider
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.votesCancellable else {
                    return
                }

                self?.votesCancellable = nil

                do {
                    let votes = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveVotes(votes)
                } catch {
                    self?.presenter?.didReceiveError(.votesFetchFailed(error))
                }
            }
        }

        votesCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension ReferendumsInteractor: ReferendumsInteractorInputProtocol {
    func setup() {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.governanceState.settings.setup(runningCompletionIn: .main) { result in
                switch result {
                case .success:
                    self?.continueSetup()
                case .failure:
                    self?.presenter?.didReceiveError(.settingsLoadFailed)
                }
            }
        }
    }

    func remakeSubscriptions() {
        clear()

        if let chain = governanceState.settings.value {
            let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest())

            setup(with: accountResponse?.accountId, chain: chain)
        }
    }

    func saveSelected(chainModel: ChainModel) {
        if chainModel.chainId != governanceState.settings.value?.chainId {
            clear()

            governanceState.settings.save(value: chainModel, runningCompletionIn: .main) { [weak self] result in
                switch result {
                case let .success(chain):
                    self?.handleChainChange(for: chain)
                case let .failure(error):
                    self?.presenter?.didReceiveError(.chainSaveFailed(error))
                }
            }
        }
    }

    func becomeOnline() {
        if let chain = governanceState.settings.value {
            subscribeToBlockNumber(for: chain)
        }
    }

    func putOffline() {
        blockNumberSubscription = nil
    }

    func refresh() {
        if governanceState.settings.value != nil {
            provideReferendumsIfNeeded()
            provideVotesIfNeeded()

            metadataProvider?.refresh()
        }
    }
}

extension ReferendumsInteractor: GovMetadataLocalStorageSubscriber, GovMetadataLocalStorageHandler {
    func handleGovMetadata(result: Result<ReferendumMetadataMapping?, Error>, chain: ChainModel) {
        guard let currentChain = governanceState.settings.value, currentChain.chainId == chain.chainId else {
            return
        }

        switch result {
        case let .success(mapping):
            presenter?.didReceiveReferendumsMetadata(mapping)
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

extension ReferendumsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil, let chain = governanceState.settings.value {
            subscribeToAssetPrice(for: chain)
        }
    }
}
