import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation

protocol BaseReferendumsInteractorInputProtocol: AnyObject {
    func setup()
    func becomeOnline()
    func putOffline()
    func refresh()
    func remakeSubscriptions()
    func retryBlockTime()
    func retryOffchainVotingFetch()
}

protocol BaseReferendumsInteractorOutputProtocol: AnyObject {
    func didReceiveReferendums(_ referendums: [ReferendumLocal])
    func didReceiveReferendumsMetadata(_ changes: [DataProviderChange<ReferendumMetadataLocal>])
    func didReceiveVoting(_ voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>)
    func didReceiveOffchainVoting(_ voting: GovernanceOffchainVotesLocal)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveError(_ error: ReferendumsInteractorError)
}

class BaseReferendumsInteractor: BaseReferendumsInteractorInputProtocol, AnyProviderAutoCleaning, AnyCancellableCleaning {
    var basePresenter: BaseReferendumsInteractorOutputProtocol?

    let selectedMetaAccount: MetaAccountModel
    let governanceState: GovernanceSharedState
    let chainRegistry: ChainRegistryProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let serviceFactory: GovernanceServiceFactoryProtocol
    let operationQueue: OperationQueue

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        governanceState.generalLocalSubscriptionFactory
    }

    private(set) var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private(set) var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?

    var referendumsCancellable: CancellableCall?
    var blockTimeCancellable: CancellableCall?
    var offchainVotingCancellable: CancellableCall?

    init(
        selectedMetaAccount: MetaAccountModel,
        governanceState: GovernanceSharedState,
        chainRegistry: ChainRegistryProtocol,
        serviceFactory: GovernanceServiceFactoryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.governanceState = governanceState
        self.chainRegistry = chainRegistry
        self.serviceFactory = serviceFactory
        self.operationQueue = operationQueue
        self.applicationHandler = applicationHandler
    }

    deinit {
        clearBlockTimeService()
        clearCancellable()
    }

    func clear() {
        clear(streamableProvider: &metadataProvider)
        clearBlockTimeService()
        clearBlockNumberSubscription()
        clearCancellable()
    }

    func clearCancellable() {
        clear(cancellable: &referendumsCancellable)
        clear(cancellable: &blockTimeCancellable)
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

    func updateReferendums(_ referendums: [ReferendumLocal]) {
        basePresenter?.didReceiveReferendums(referendums)
    }

    func updateReferendumsMetadata(_ changes: [DataProviderChange<ReferendumMetadataLocal>]) {
        basePresenter?.didReceiveReferendumsMetadata(changes)
    }

    func setup() {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.governanceState.settings.setup(runningCompletionIn: .main) { result in
                switch result {
                case .success:
                    self?.continueSetup()
                case .failure:
                    self?.basePresenter?.didReceiveError(.settingsLoadFailed)
                }
            }
        }
    }

    func setup(with accountId: AccountId?, option: GovernanceSelectedOption) {
        setupBlockTimeService(for: option.chain)
        provideBlockTime()

        subscribeToBlockNumber(for: option.chain)
        subscribeToMetadata(for: option)

        if let accountId = accountId {
            subscribeAccountVotes(for: accountId)
        } else {
            basePresenter?.didReceiveVoting(.init(value: nil, blockHash: nil))
        }
    }

    func continueSetup() {
        applicationHandler.delegate = self

        guard let option = governanceState.settings.value else {
            basePresenter?.didReceiveError(.settingsLoadFailed)
            return
        }

        let accountResponse = selectedMetaAccount.fetch(for: option.chain.accountRequest())

        setup(with: accountResponse?.accountId, option: option)
    }

    private func setupBlockTimeService(for chain: ChainModel) {
        do {
            let blockTimeService = try serviceFactory.createBlockTimeService(for: chain.chainId)

            governanceState.replaceBlockTimeService(blockTimeService)

            blockTimeService.setup()
        } catch {
            basePresenter?.didReceiveError(.blockTimeServiceFailed(error))
        }
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
            basePresenter?.didReceiveError(.blockTimeFetchFailed(ChainRegistryError.runtimeMetadaUnavailable))
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

                    self?.basePresenter?.didReceiveBlockTime(blockTime)
                } catch {
                    self?.basePresenter?.didReceiveError(.blockTimeFetchFailed(error))
                }
            }
        }

        blockTimeCancellable = blockTimeWrapper

        operationQueue.addOperations(blockTimeWrapper.allOperations, waitUntilFinished: false)
    }

    func subscribeToBlockNumber(for chain: ChainModel) {
        guard blockNumberSubscription == nil else {
            return
        }

        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)
    }

    private func subscribeToMetadata(for option: GovernanceSelectedOption) {
        metadataProvider = subscribeGovernanceMetadata(for: option)

        if metadataProvider == nil {
            updateReferendumsMetadata([])
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

    func becomeOnline() {
        if let chain = governanceState.settings.value?.chain {
            subscribeToBlockNumber(for: chain)
        }
    }

    func putOffline() {
        clearBlockNumberSubscription()
    }

    func refresh() {
        if governanceState.settings.value != nil {
            provideReferendumsIfNeeded()
            provideBlockTime()

            metadataProvider?.refresh()

            provideOffchainVotingIfNeeded()
        }
    }

    func retryBlockTime() {
        provideBlockTime()
    }

    func retryOffchainVotingFetch() {
        provideOffchainVotingIfNeeded()
    }

    func provideReferendumsIfNeeded() {
        guard referendumsCancellable == nil else {
            return
        }

        guard let chain = governanceState.settings.value?.chain else {
            basePresenter?.didReceiveError(.referendumsFetchFailed(PersistentValueSettingsError.missingValue))
            return
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            basePresenter?.didReceiveError(.referendumsFetchFailed(ChainRegistryError.connectionUnavailable))
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            basePresenter?.didReceiveError(.referendumsFetchFailed(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        guard let referendumsOperationFactory = governanceState.referendumsOperationFactory else {
            updateReferendums([])
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
                    self?.updateReferendums(referendums)
                } catch {
                    self?.basePresenter?.didReceiveError(.referendumsFetchFailed(error))
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
                self?.basePresenter?.didReceiveVoting(voting)
            case let .failure(error):
                self?.basePresenter?.didReceiveError(.votingSubscriptionFailed(error))
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
            let address = selectedMetaAccount.fetch(for: option.chain.accountRequest())?.toAddress(),
            let connection = governanceState.chainRegistry.getConnection(for: option.chain.chainId),
            let runtimeProvider = governanceState.chainRegistry.getRuntimeProvider(for: option.chain.chainId) else {
            return
        }

        clear(cancellable: &offchainVotingCancellable)

        let votingWrapper = offchainOperationFactory.createWrapper(
            for: address,
            chain: option.chain,
            connection: connection,
            runtimeService: runtimeProvider
        )

        votingWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.offchainVotingCancellable === votingWrapper else {
                    return
                }

                self?.offchainVotingCancellable = nil

                do {
                    let voting = try votingWrapper.targetOperation.extractNoCancellableResultData()

                    self?.basePresenter?.didReceiveOffchainVoting(voting)
                } catch {
                    self?.basePresenter?.didReceiveError(.offchainVotingFetchFailed(error))
                }
            }
        }

        offchainVotingCancellable = votingWrapper

        operationQueue.addOperations(votingWrapper.allOperations, waitUntilFinished: false)
    }
}

extension BaseReferendumsInteractor: GovMetadataLocalStorageSubscriber, GovMetadataLocalStorageHandler {
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
            updateReferendumsMetadata(changes)
        case let .failure(error):
            basePresenter?.didReceiveError(.metadataSubscriptionFailed(error))
        }
    }
}

extension BaseReferendumsInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId: ChainModel.Id) {
        guard let chain = governanceState.settings.value?.chain, chain.chainId == chainId else {
            return
        }

        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                basePresenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            basePresenter?.didReceiveError(.blockNumberSubscriptionFailed(error))
        }
    }
}

extension BaseReferendumsInteractor: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        clearCancellable()
        governanceState.subscriptionFactory?.cancelCancellable()
    }
}
