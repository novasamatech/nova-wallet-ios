import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation

final class ReferendumsInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: ReferendumsInteractorOutputProtocol?

    let selectedMetaAccount: MetaAccountModel
    let governanceState: GovernanceSharedState
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let serviceFactory: GovernanceServiceFactoryProtocol
    let operationQueue: OperationQueue

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        governanceState.generalLocalSubscriptionFactory
    }

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    private var referendumsCancellable: CancellableCall?
    private var blockTimeCancellable: CancellableCall?
    private var unlockScheduleCancellable: CancellableCall?

    init(
        selectedMetaAccount: MetaAccountModel,
        governanceState: GovernanceSharedState,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        serviceFactory: GovernanceServiceFactoryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.governanceState = governanceState
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.serviceFactory = serviceFactory
        self.operationQueue = operationQueue
        self.applicationHandler = applicationHandler
        self.currencyManager = currencyManager
    }

    deinit {
        clearBlockTimeService()
        clearCancellable()
    }

    private func clear() {
        clear(streamableProvider: &assetBalanceProvider)
        clear(singleValueProvider: &priceProvider)
        clear(streamableProvider: &metadataProvider)

        clearBlockTimeService()
        clearSubscriptionFactory()

        blockNumberSubscription = nil

        clearCancellable()
    }

    private func clearCancellable() {
        clear(cancellable: &referendumsCancellable)
        clear(cancellable: &blockTimeCancellable)
        clear(cancellable: &unlockScheduleCancellable)
    }

    private func clearBlockTimeService() {
        governanceState.blockTimeService?.throttle()
        governanceState.replaceBlockTimeService(nil)
    }

    private func clearSubscriptionFactory() {
        governanceState.replaceGovernanceFactory(for: nil)
    }

    private func continueSetup() {
        applicationHandler.delegate = self

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

        setupBlockTimeService(for: chain)
        provideBlockTime()

        setupSubscriptionFactory(for: chain)

        subscribeToBlockNumber(for: chain)
        subscribeToMetadata(for: chain)

        if let accountId = accountId {
            subscribeAccountVotes(for: accountId)
        } else {
            presenter?.didReceiveVoting(.init(value: nil, blockHash: nil))
        }
    }

    private func setupBlockTimeService(for chain: ChainModel) {
        do {
            let blockTimeService = try serviceFactory.createBlockTimeService(for: chain.chainId)

            governanceState.replaceBlockTimeService(blockTimeService)

            blockTimeService.setup()
        } catch {
            presenter?.didReceiveError(.blockTimeServiceFailed(error))
        }
    }

    private func setupSubscriptionFactory(for chain: ChainModel) {
        governanceState.replaceGovernanceFactory(for: chain)
    }

    private func subscribeToBlockNumber(for chain: ChainModel) {
        guard blockNumberSubscription == nil else {
            return
        }

        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)
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
        metadataProvider = subscribeGovernanceMetadata(for: chain)

        if metadataProvider == nil {
            presenter?.didReceiveReferendumsMetadata([])
        }
    }

    private func handleChainChange(for newChain: ChainModel) {
        clear()

        let accountResponse = selectedMetaAccount.fetch(for: newChain.accountRequest())

        setup(with: accountResponse?.accountId, chain: newChain)
    }

    private func provideBlockTime() {
        guard
            blockTimeCancellable == nil,
            let blockTimeService = governanceState.blockTimeService,
            let blockTimeFactory = governanceState.createBlockTimeOperationFactory(),
            let chain = governanceState.settings.value else {
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            presenter?.didReceiveError(.blockTimeFetchFailed(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        let blockTimeWrapper = blockTimeFactory.createBlockTimeOperation(
            from: runtimeProvider,
            blockTimeEstimationService: blockTimeService
        )

        blockTimeWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.blockTimeCancellable === blockTimeWrapper else {
                    return
                }

                self?.blockTimeCancellable = nil

                do {
                    let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()

                    self?.presenter?.didReceiveBlockTime(blockTime)
                } catch {
                    self?.presenter?.didReceiveError(.blockTimeFetchFailed(error))
                }
            }
        }

        blockTimeCancellable = blockTimeWrapper

        operationQueue.addOperations(blockTimeWrapper.allOperations, waitUntilFinished: false)
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

        guard let referendumsOperationFactory = governanceState.referendumsOperationFactory else {
            presenter?.didReceiveReferendums([])
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

    private func subscribeAccountVotes(for accountId: AccountId) {
        guard let subscriptionFactory = governanceState.subscriptionFactory else {
            return
        }

        subscriptionFactory.subscribeToAccountVotes(self, accountId: accountId) { [weak self] result in
            switch result {
            case let .success(voting):
                self?.presenter?.didReceiveVoting(voting)
            case let .failure(error):
                self?.presenter?.didReceiveError(.votingSubscriptionFailed(error))
            case .none:
                break
            }
        }
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

        blockNumberSubscription?.removeObserver(self)
        blockNumberSubscription = nil

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
        blockNumberSubscription?.removeObserver(self)
        blockNumberSubscription = nil
    }

    func refresh() {
        if governanceState.settings.value != nil {
            provideReferendumsIfNeeded()
            provideBlockTime()

            metadataProvider?.refresh()
        }
    }

    func refreshUnlockSchedule(for tracksVoting: ReferendumTracksVotingDistribution, blockHash: Data?) {
        if let chain = governanceState.settings.value {
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
}

extension ReferendumsInteractor: GovMetadataLocalStorageSubscriber, GovMetadataLocalStorageHandler {
    var govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol {
        governanceState.govMetadataLocalSubscriptionFactory
    }

    func handleGovernanceMetadataPreview(
        result: Result<[DataProviderChange<ReferendumMetadataLocal>], Error>,
        chain: ChainModel
    ) {
        guard let currentChain = governanceState.settings.value, currentChain.chainId == chain.chainId else {
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
        guard let chain = governanceState.settings.value, chain.chainId == chainId else {
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
        if presenter != nil, let chain = governanceState.settings.value {
            subscribeToAssetPrice(for: chain)
        }
    }
}

extension ReferendumsInteractor: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        clearCancellable()
    }
}
