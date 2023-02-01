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
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let operationQueue: OperationQueue

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        governanceState.generalLocalSubscriptionFactory
    }

    private(set) var priceProvider: AnySingleValueProvider<PriceData>?
    private(set) var assetBalanceProvider: StreamableProvider<AssetBalance>?
    private(set) var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private(set) var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?

    private(set) lazy var localKeyFactory = LocalStorageKeyFactory()

    var referendumsCancellable: CancellableCall?
    var blockTimeCancellable: CancellableCall?
    var unlockScheduleCancellable: CancellableCall?
    var offchainVotingCancellable: CancellableCall?

    init(
        selectedMetaAccount: MetaAccountModel,
        governanceState: GovernanceSharedState,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
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
        self.identityOperationFactory = identityOperationFactory
        self.currencyManager = currencyManager
    }

    deinit {
        clearBlockTimeService()
        clearCancellable()
    }

    func clear() {
        clear(streamableProvider: &assetBalanceProvider)
        clear(singleValueProvider: &priceProvider)
        clear(streamableProvider: &metadataProvider)

        clearBlockTimeService()
        clearSubscriptionFactory()
        clearOffchainServices()

        clearBlockNumberSubscription()

        clearCancellable()
    }

    func clearCancellable() {
        clear(cancellable: &referendumsCancellable)
        clear(cancellable: &blockTimeCancellable)
        clear(cancellable: &unlockScheduleCancellable)
        clear(cancellable: &offchainVotingCancellable)
    }

    private func clearBlockTimeService() {
        governanceState.blockTimeService?.throttle()
        governanceState.replaceBlockTimeService(nil)
    }

    private func clearSubscriptionFactory() {
        governanceState.replaceGovernanceFactory(for: nil)
    }

    private func clearOffchainServices() {
        governanceState.replaceGovernanceOffchainServices(for: nil)
    }

    func clearBlockNumberSubscription() {
        blockNumberSubscription?.removeObserver(self)
        blockNumberSubscription = nil
    }

    func continueSetup() {
        applicationHandler.delegate = self

        guard let option = governanceState.settings.value else {
            presenter?.didReceiveError(.settingsLoadFailed)
            return
        }

        let accountResponse = selectedMetaAccount.fetch(for: option.chain.accountRequest())

        setup(with: accountResponse?.accountId, option: option)
    }

    func setup(with accountId: AccountId?, option: GovernanceSelectedOption) {
        presenter?.didReceiveSelectedOption(option)

        if let accountId = accountId {
            subscribeToAssetBalance(for: accountId, chain: option.chain)
        } else {
            presenter?.didReceiveAssetBalance(nil)
        }

        subscribeToAssetPrice(for: option.chain)

        setupBlockTimeService(for: option.chain)
        provideBlockTime()

        setupSubscriptionFactory(for: option)
        setupOffchainServices(for: option)

        subscribeToBlockNumber(for: option.chain)
        subscribeToMetadata(for: option)
        subscribeToDelegationMetadataIfNeeded()

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

    private func setupSubscriptionFactory(for option: GovernanceSelectedOption) {
        governanceState.replaceGovernanceFactory(for: option)
    }

    private func setupOffchainServices(for option: GovernanceSelectedOption) {
        governanceState.replaceGovernanceOffchainServices(for: option)
    }

    func subscribeToBlockNumber(for chain: ChainModel) {
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

    func subscribeToAssetPrice(for chain: ChainModel) {
        guard let priceId = chain.utilityAsset()?.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func subscribeToMetadata(for option: GovernanceSelectedOption) {
        metadataProvider = subscribeGovernanceMetadata(for: option)

        if metadataProvider == nil {
            presenter?.didReceiveReferendumsMetadata([])
        }
    }

    private func subscribeToDelegationMetadataIfNeeded() {
        guard let delegationMetadataProvider = governanceState.delegationsMetadataProvider else {
            return
        }

        delegationMetadataProvider.removeObserver(self)

        let updateClosure: ([DataProviderChange<[GovernanceDelegateMetadataRemote]>]) -> Void = { [weak self] changes in
            if let metadata = changes.reduceToLastChange() {
                self?.presenter?.didReceiveDelegationsMetadata(metadata)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceiveError(.delegationMetadataSubscriptionFailed(error))
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)

        delegationMetadataProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func handleOptionChange(for newOption: GovernanceSelectedOption) {
        clear()

        let chain = newOption.chain
        let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest())

        setup(with: accountResponse?.accountId, option: newOption)
    }

    func provideBlockTime() {
        guard
            blockTimeCancellable == nil,
            let blockTimeService = governanceState.blockTimeService,
            let blockTimeFactory = governanceState.createBlockTimeOperationFactory(),
            let chain = governanceState.settings.value?.chain else {
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

    func provideReferendumsIfNeeded() {
        guard referendumsCancellable == nil else {
            return
        }

        guard let chain = governanceState.settings.value?.chain else {
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

    func provideOffchainVotingIfNeeded() {
        if offchainVotingCancellable == nil {
            provideOffchainVoting()
        }
    }

    func provideOffchainVoting() {
        guard
            let offchainOperationFactory = governanceState.offchainVotingFactory,
            let chain = governanceState.settings.value?.chain,
            let address = selectedMetaAccount.fetch(for: chain.accountRequest())?.toAddress(),
            let connection = governanceState.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = governanceState.chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return
        }

        clear(cancellable: &offchainVotingCancellable)

        let votingWrapper = offchainOperationFactory.createAllVotesFetchOperation(for: address)

        let identityWrapper = identityOperationFactory.createIdentityWrapperByAccountId(
            for: {
                let delegates = try votingWrapper.targetOperation.extractNoCancellableResultData().getAllDelegates()
                return Array(delegates)
            },
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chain.chainFormat
        )

        identityWrapper.addDependency(wrapper: votingWrapper)

        let cancellableWrapper = CompoundOperationWrapper(
            targetOperation: identityWrapper.targetOperation,
            dependencies: votingWrapper.allOperations + identityWrapper.dependencies
        )

        identityWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.offchainVotingCancellable === cancellableWrapper else {
                    return
                }

                self?.offchainVotingCancellable = nil

                do {
                    let voting = try votingWrapper.targetOperation.extractNoCancellableResultData()
                    let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()

                    self?.presenter?.didReceiveOffchainVoting(voting, identities: identities)
                } catch {
                    self?.presenter?.didReceiveError(.offchainVotingFetchFailed(error))
                }
            }
        }

        offchainVotingCancellable = cancellableWrapper

        operationQueue.addOperations(cancellableWrapper.allOperations, waitUntilFinished: false)
    }
}
