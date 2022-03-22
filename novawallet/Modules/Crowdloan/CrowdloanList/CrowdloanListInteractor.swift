import UIKit
import RobinHood
import SoraFoundation

final class CrowdloanListInteractor: RuntimeConstantFetching {
    weak var presenter: CrowdloanListInteractorOutputProtocol!

    let selectedMetaAccount: MetaAccountModel
    let crowdloanState: CrowdloanSharedState
    let crowdloanOperationFactory: CrowdloanOperationFactoryProtocol
    let jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let crowdloanRemoteSubscriptionService: CrowdloanRemoteSubscriptionServiceProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let operationManager: OperationManagerProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let logger: LoggerProtocol?

    private var blockNumberSubscriptionId: UUID?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var crowdloansRequest: CompoundOperationWrapper<[Crowdloan]>?
    private var onchainContributionsOperation: Operation?
    private var latestCrowdloanIndexes: [UInt32]?
    private var leaseInfoWrapper: CompoundOperationWrapper<[ParachainLeaseInfo]>?
    private var leaseInfoParams: [LeaseParam]?
    private var displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>?
    private var externalContributionsProvider: AnySingleValueProvider<[ExternalContribution]>?

    deinit {
        if let subscriptionId = blockNumberSubscriptionId, let chain = crowdloanState.settings.value {
            blockNumberSubscriptionId = nil
            crowdloanRemoteSubscriptionService.detach(for: subscriptionId, chainId: chain.chainId)
        }
    }

    init(
        selectedMetaAccount: MetaAccountModel,
        crowdloanState: CrowdloanSharedState,
        chainRegistry: ChainRegistryProtocol,
        crowdloanOperationFactory: CrowdloanOperationFactoryProtocol,
        crowdloanRemoteSubscriptionService: CrowdloanRemoteSubscriptionServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.crowdloanState = crowdloanState
        self.crowdloanOperationFactory = crowdloanOperationFactory
        self.chainRegistry = chainRegistry
        self.jsonDataProviderFactory = jsonDataProviderFactory
        self.crowdloanRemoteSubscriptionService = crowdloanRemoteSubscriptionService
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.operationManager = operationManager
        self.applicationHandler = applicationHandler
        self.logger = logger
    }

    private func clearOnchainContributionRequest(_ shouldCancel: Bool) {
        let operation = onchainContributionsOperation
        onchainContributionsOperation = nil
        latestCrowdloanIndexes = nil

        if shouldCancel {
            operation?.cancel()
        }
    }

    private func clearLeaseInfoRequest(_ shouldCancel: Bool) {
        let wrapper = leaseInfoWrapper
        leaseInfoWrapper = nil
        leaseInfoParams = nil

        if shouldCancel {
            wrapper?.cancel()
        }
    }

    private func clearCrowdloansRequest(_ shouldCancel: Bool) {
        let wrapper = crowdloansRequest
        crowdloansRequest = nil

        if shouldCancel {
            wrapper?.cancel()
        }
    }

    private func provideOnchainContributions(
        for crowdloans: [Crowdloan],
        chain: ChainModel,
        connection: ChainConnection,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        let newCrowdloanIndexes = crowdloans.map(\.fundInfo.index)

        guard latestCrowdloanIndexes != newCrowdloanIndexes else {
            return
        }

        clearOnchainContributionRequest(true)

        guard !crowdloans.isEmpty else {
            presenter.didReceiveContributions(result: .success([:]))
            return
        }

        guard let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest()) else {
            presenter.didReceiveContributions(result: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        let contributionsOperation: BaseOperation<[CrowdloanContributionResponse]> =
            OperationCombiningService(operationManager: operationManager) { [weak self] in
                guard let strongSelf = self else {
                    return []
                }

                return newCrowdloanIndexes.map { index in
                    strongSelf.crowdloanOperationFactory.fetchContributionOperation(
                        connection: connection,
                        runtimeService: runtimeService,
                        accountId: accountResponse.accountId,
                        index: index
                    )
                }
            }.longrunOperation()

        contributionsOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard contributionsOperation === self?.onchainContributionsOperation else {
                    return
                }

                self?.clearOnchainContributionRequest(false)

                do {
                    let contributions = try contributionsOperation.extractNoCancellableResultData().toDict()
                    self?.presenter.didReceiveContributions(result: .success(contributions))
                } catch {
                    if
                        let encodingError = error as? StorageKeyEncodingOperationError,
                        encodingError == .invalidStoragePath {
                        self?.presenter.didReceiveContributions(result: .success([:]))
                    } else {
                        self?.presenter.didReceiveContributions(result: .failure(error))
                    }
                }
            }
        }

        latestCrowdloanIndexes = newCrowdloanIndexes
        onchainContributionsOperation = contributionsOperation

        operationManager.enqueue(operations: [contributionsOperation], in: .transient)
    }

    private func provideLeaseInfo(
        for crowdloans: [Crowdloan],
        connection: ChainConnection,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        let newLeaseParams: [LeaseParam] = crowdloans.map { crowdloan in
            let bidderKey = crowdloan.fundInfo.getBidderKey(for: crowdloan.paraId)
            return LeaseParam(paraId: crowdloan.paraId, bidderKey: bidderKey)
        }

        guard leaseInfoParams != newLeaseParams else {
            return
        }

        clearLeaseInfoRequest(true)

        guard !crowdloans.isEmpty else {
            presenter.didReceiveLeaseInfo(result: .success([:]))
            return
        }

        let queryWrapper = crowdloanOperationFactory.fetchLeaseInfoOperation(
            connection: connection,
            runtimeService: runtimeService,
            params: newLeaseParams
        )

        queryWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.leaseInfoWrapper === queryWrapper else {
                    return
                }

                self?.clearLeaseInfoRequest(false)

                do {
                    let leaseInfo = try queryWrapper.targetOperation.extractNoCancellableResultData().toMap()
                    self?.presenter.didReceiveLeaseInfo(result: .success(leaseInfo))
                } catch {
                    if
                        let encodingError = error as? StorageKeyEncodingOperationError,
                        encodingError == .invalidStoragePath {
                        self?.presenter.didReceiveLeaseInfo(result: .success([:]))
                    } else {
                        self?.presenter.didReceiveLeaseInfo(result: .failure(error))
                    }
                }
            }
        }

        leaseInfoWrapper = queryWrapper
        leaseInfoParams = newLeaseParams

        operationManager.enqueue(operations: queryWrapper.allOperations, in: .transient)
    }

    private func notifyCrowdolansFetchWithError(error: Error) {
        presenter.didReceiveCrowdloans(result: .failure(error))
        presenter.didReceiveContributions(result: .failure(error))
        presenter.didReceiveLeaseInfo(result: .failure(error))
    }

    private func subscribeToDisplayInfo(for chain: ChainModel) {
        displayInfoProvider = nil

        guard let crowdloanUrl = chain.externalApi?.crowdloans?.url else {
            presenter.didReceiveDisplayInfo(result: .success([:]))
            return
        }

        displayInfoProvider = jsonDataProviderFactory.getJson(for: crowdloanUrl)

        let updateClosure: ([DataProviderChange<CrowdloanDisplayInfoList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.presenter.didReceiveDisplayInfo(result: .success(result.toMap()))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceiveDisplayInfo(result: .failure(error))
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true, waitsInProgressSyncOnAdd: false)

        displayInfoProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func subscribeToAccountInfo(for accountId: AccountId, chain: ChainModel) {
        accountInfoProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId)
    }

    private func subscribeToExternalContributions(for accountId: AccountId, chain: ChainModel) {
        externalContributionsProvider = subscribeToExternalContributionsProvider(for: accountId, chain: chain)
    }

    private func provideConstants(for chain: ChainModel) {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            let error = ChainRegistryError.runtimeMetadaUnavailable
            presenter.didReceiveBlockDuration(result: .failure(error))
            presenter.didReceiveLeasingPeriod(result: .failure(error))
            return
        }

        fetchConstant(
            for: .babeBlockTime,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BlockTime, Error>) in
            self?.presenter.didReceiveBlockDuration(result: result)
        }

        fetchConstant(
            for: .paraLeasingPeriod,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<LeasingPeriod, Error>) in
            self?.presenter.didReceiveLeasingPeriod(result: result)
        }
    }
}

extension CrowdloanListInteractor {
    func setup(with accountId: AccountId, chain: ChainModel) {
        presenter.didReceiveSelectedChain(result: .success(chain))

        subscribeToAccountInfo(for: accountId, chain: chain)
        subscribeToExternalContributions(for: accountId, chain: chain)

        provideCrowdloans(for: chain)

        subscribeToDisplayInfo(for: chain)

        provideConstants(for: chain)
    }

    func refresh(with chain: ChainModel) {
        displayInfoProvider?.refresh()
        externalContributionsProvider?.refresh()

        provideCrowdloans(for: chain)

        provideConstants(for: chain)
    }

    func clear() {
        if let oldChain = crowdloanState.settings.value {
            putOffline(with: oldChain)
        }

        clear(singleValueProvider: &displayInfoProvider)
        clear(dataProvider: &accountInfoProvider)
        clear(singleValueProvider: &externalContributionsProvider)

        cancelCrowdloansOnchainRequests()
    }

    func cancelCrowdloansOnchainRequests() {
        clearCrowdloansRequest(true)
        clearOnchainContributionRequest(true)
        clearLeaseInfoRequest(true)
    }

    func handleSelectionChange(to chain: ChainModel) {
        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            presenter.didReceiveAccountInfo(
                result: .failure(ChainAccountFetchingError.accountNotExists)
            )
            return
        }

        setup(with: accountId, chain: chain)
        becomeOnline(with: chain)
    }

    func becomeOnline(with chain: ChainModel) {
        if blockNumberSubscriptionId == nil {
            blockNumberSubscriptionId = crowdloanRemoteSubscriptionService.attach(for: chain.chainId)
        }

        if blockNumberProvider == nil {
            blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
        }

        externalContributionsProvider?.refresh()
    }

    func putOffline(with chain: ChainModel) {
        if let subscriptionId = blockNumberSubscriptionId {
            blockNumberSubscriptionId = nil
            crowdloanRemoteSubscriptionService.detach(for: subscriptionId, chainId: chain.chainId)
        }

        clear(dataProvider: &blockNumberProvider)
    }

    func provideCrowdloans(for chain: ChainModel) {
        guard crowdloansRequest == nil else {
            return
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            notifyCrowdolansFetchWithError(error: ChainRegistryError.connectionUnavailable)
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            notifyCrowdolansFetchWithError(error: ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        let crowdloanWrapper = crowdloanOperationFactory.fetchCrowdloansOperation(
            connection: connection,
            runtimeService: runtimeService
        )

        crowdloansRequest = crowdloanWrapper

        crowdloanWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.crowdloansRequest === crowdloanWrapper else {
                    return
                }

                self?.clearCrowdloansRequest(false)

                do {
                    let crowdloans = try crowdloanWrapper.targetOperation.extractNoCancellableResultData()
                    self?.provideOnchainContributions(
                        for: crowdloans,
                        chain: chain,
                        connection: connection,
                        runtimeService: runtimeService
                    )

                    self?.provideLeaseInfo(
                        for: crowdloans,
                        connection: connection,
                        runtimeService: runtimeService
                    )
                    self?.presenter.didReceiveCrowdloans(result: .success(crowdloans))
                } catch {
                    if
                        let encodingError = error as? StorageKeyEncodingOperationError,
                        encodingError == .invalidStoragePath {
                        self?.presenter.didReceiveCrowdloans(result: .success([]))
                        self?.presenter.didReceiveContributions(result: .success([:]))
                        self?.presenter.didReceiveLeaseInfo(result: .success([:]))
                    } else {
                        self?.notifyCrowdolansFetchWithError(error: error)
                    }
                }
            }
        }

        operationManager.enqueue(operations: crowdloanWrapper.allOperations, in: .transient)
    }
}
