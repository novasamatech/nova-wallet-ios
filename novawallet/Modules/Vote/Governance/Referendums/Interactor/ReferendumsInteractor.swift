import Foundation
import Operation_iOS
import SubstrateSdk
import Foundation_iOS

final class ReferendumsInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: ReferendumsInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let selectedMetaAccount: MetaAccountModel
    let governanceState: GovernanceSharedState
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let serviceFactory: VoteServiceFactoryProtocol
    let operationQueue: OperationQueue

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        governanceState.generalLocalSubscriptionFactory
    }

    private(set) var priceProvider: StreamableProvider<PriceData>?
    private(set) var assetBalanceProvider: StreamableProvider<AssetBalance>?
    private(set) var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private(set) var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?

    private(set) lazy var localKeyFactory = LocalStorageKeyFactory()

    var referendumsCancellable: CancellableCall?
    var blockTimeCancellable: CancellableCall?
    var unlockScheduleCancellable: CancellableCall?
    var offchainVotingCancellable: CancellableCall?

    var timelineChainId: ChainModel.Id? {
        let chain = governanceState.settings.value?.chain

        return chain?.timelineChain ?? chain?.chainId
    }

    init(
        eventCenter: EventCenterProtocol,
        selectedMetaAccount: MetaAccountModel,
        governanceState: GovernanceSharedState,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        serviceFactory: VoteServiceFactoryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.eventCenter = eventCenter
        self.selectedMetaAccount = selectedMetaAccount
        self.governanceState = governanceState
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.serviceFactory = serviceFactory
        self.operationQueue = operationQueue
        self.applicationHandler = applicationHandler
        self.currencyManager = currencyManager
        self.localizationManager = localizationManager

        self.eventCenter.add(observer: self)
    }

    deinit {
        clearBlockTimeService()
        clearCancellable()
    }

    func clear() {
        clear(streamableProvider: &assetBalanceProvider)
        clear(streamableProvider: &priceProvider)
        clear(streamableProvider: &metadataProvider)

        clearBlockTimeService()
        clearSubscriptionFactory()

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
        provideDelegationsSupport(for: option)

        if let accountId = accountId {
            subscribeToAssetBalance(for: accountId, chain: option.chain)
        } else {
            presenter?.didReceiveAssetBalance(nil)
        }

        subscribeToAssetPrice(for: option.chain)

        setupBlockTimeService(for: option.chain)
        provideBlockTime()

        setupSubscriptionFactory(for: option)

        setupSwipeGovService(for: option)

        subscribeToBlockNumber(for: option.chain)
        subscribeToMetadata(for: option)

        if let accountId = accountId {
            subscribeAccountVotes(for: accountId)
        } else {
            presenter?.didReceiveVoting(.init(value: nil, blockHash: nil))
        }
    }

    private func setupBlockTimeService(for chain: ChainModel) {
        do {
            let timelineChain = try chainRegistry.getTimelineChainOrError(for: chain.chainId)
            let blockTimeService = try serviceFactory.createBlockTimeService(for: timelineChain.chainId)

            governanceState.replaceBlockTimeService(blockTimeService)

            blockTimeService.setup()
        } catch {
            presenter?.didReceiveError(.blockTimeServiceFailed(error))
        }
    }

    private func setupSubscriptionFactory(for option: GovernanceSelectedOption) {
        governanceState.replaceGovernanceFactory(for: option)
    }

    func setupSwipeGovService(for option: GovernanceSelectedOption) {
        governanceState.replaceSwipeGovService(for: option, language: selectedLocale.languageCodeOrEn)

        guard let swipeGovService = governanceState.swipeGovService else {
            presenter?.didReceiveSwipeGovEligible([])
            return
        }

        governanceState.observableState.addObserver(
            with: swipeGovService,
            sendStateOnSubscription: true,
            queue: .global()
        ) { [weak swipeGovService] _, newState in
            let filteredReferendums = ReferendumFilter.VoteAvailable(
                referendums: newState.value.referendums,
                accountVotes: newState.value.voting?.value?.votes
            ).callAsFunction()

            swipeGovService?.update(referendums: Set(filteredReferendums.keys))
        }

        swipeGovService.subscribeReferendums(
            for: self,
            notifyingIn: .main
        ) { [weak self] _, eligibleReferendums in
            self?.presenter?.didReceiveSwipeGovEligible(eligibleReferendums)
        }
    }

    func subscribeToBlockNumber(for _: ChainModel) {
        guard
            blockNumberSubscription == nil,
            let timelineChainId else {
            return
        }

        blockNumberSubscription = subscribeToBlockNumber(for: timelineChainId)
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
        } else {
            metadataProvider?.refresh()
        }
    }

    func handleOptionChange(for newOption: GovernanceSelectedOption) {
        clear()

        let chain = newOption.chain
        let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest())

        setup(with: accountResponse?.accountId, option: newOption)
    }

    func provideDelegationsSupport(for newOption: GovernanceSelectedOption) {
        presenter?.didReceiveSupportDelegations(governanceState.supportsDelegations(for: newOption))
    }

    func provideBlockTime() {
        guard
            blockTimeCancellable == nil,
            let timelineService = governanceState.createChainTimelineFacade() else {
            return
        }

        let blockTimeWrapper = timelineService.createBlockTimeOperation()

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
        if offchainVotingCancellable == nil, let option = governanceState.settings.value {
            provideOffchainVoting(for: option)
        }
    }

    func provideOffchainVoting(for option: GovernanceSelectedOption) {
        guard
            let offchainOperationFactory = governanceState.createOffchainAllVotesFactory(
                for: option
            ),
            let address = selectedMetaAccount.fetch(for: option.chain.accountRequest())?.toAddress() else {
            return
        }

        clear(cancellable: &offchainVotingCancellable)

        let votingWrapper = offchainOperationFactory.createWrapper(
            for: address
        )

        votingWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.offchainVotingCancellable === votingWrapper else {
                    return
                }

                self?.offchainVotingCancellable = nil

                do {
                    let voting = try votingWrapper.targetOperation.extractNoCancellableResultData()

                    self?.presenter?.didReceiveOffchainVoting(voting)
                } catch {
                    self?.presenter?.didReceiveError(.offchainVotingFetchFailed(error))
                }
            }
        }

        offchainVotingCancellable = votingWrapper

        operationQueue.addOperations(votingWrapper.allOperations, waitUntilFinished: false)
    }

    func setupState(onSuccess: @escaping (GovernanceSelectedOption?) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.governanceState.settings.setup(runningCompletionIn: .main) { result in
                switch result {
                case let .success(option):
                    onSuccess(option)
                case .failure:
                    self?.presenter?.didReceiveError(.settingsLoadFailed)
                }
            }
        }
    }
}

extension ReferendumsInteractor: EventVisitorProtocol {
    func processNetworkEnableChanged(event: NetworkEnabledChanged) {
        guard governanceState.settings.value.chain.chainId == event.chainId else {
            return
        }

        setupState { [weak self] option in
            if let option {
                self?.handleOptionChange(for: option)
            }
        }
    }
}
