import UIKit
import SubstrateSdk
import RobinHood

final class GovernanceDelegateSearchInteractor {
    weak var presenter: GovernanceDelegateSearchInteractorOutputProtocol?

    let delegateListOperationFactory: GovernanceDelegateListFactoryProtocol
    let lastVotedDays: Int
    let connection: JSONRPCEngine
    let runtimeService: RuntimeProviderProtocol
    let metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeFactory: BlockTimeOperationFactoryProtocol
    let chain: ChainModel
    let operationQueue: OperationQueue

    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private var currentBlockNumber: BlockNumber?

    init(
        delegateListOperationFactory: GovernanceDelegateListFactoryProtocol,
        lastVotedDays: Int,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        chain: ChainModel,
        operationQueue: OperationQueue
    ) {
        self.delegateListOperationFactory = delegateListOperationFactory
        self.lastVotedDays = lastVotedDays
        self.connection = connection
        self.runtimeService = runtimeService
        self.metadataProvider = metadataProvider
        self.identityOperationFactory = identityOperationFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
        self.chain = chain
        self.operationQueue = operationQueue
    }

    private func fetchDelegates() {
        guard let currentBlockNumber = currentBlockNumber else {
            return
        }

        let wrapper = delegateListOperationFactory.fetchDelegateListByBlockNumber(
            .init(
                currentBlockNumber: currentBlockNumber,
                lastVotedDays: lastVotedDays,
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: blockTimeFactory
            ),
            chain: chain,
            connection: connection,
            runtimeService: runtimeService,
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let delegates = try wrapper.targetOperation.extractNoCancellableResultData()
                    let delegatesDic = delegates?.reduce(into: [AccountAddress: GovernanceDelegateLocal]()) {
                        $0[$1.stats.address] = $1
                    }

                    self?.presenter?.didReceiveDelegates(delegatesDic ?? [:])
                } catch {
                    self?.presenter?.didReceiveError(.delegateFetchFailed(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func subscribeBlockNumber() {
        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)
    }

    private func clearAndSubscribeMetadata() {
        metadataProvider.removeObserver(self)

        let updateClosure: ([DataProviderChange<[GovernanceDelegateMetadataRemote]>]) -> Void = { [weak self] changes in
            let metadata = changes.reduceToLastChange()
            self?.presenter?.didReceiveMetadata(metadata)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceiveError(.metadataSubscriptionFailed(error))
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)

        metadataProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}

extension GovernanceDelegateSearchInteractor: GovernanceDelegateSearchInteractorInputProtocol {
    func setup() {
        clearAndSubscribeMetadata()
        subscribeBlockNumber()
    }

    func refreshDelegates() {
        fetchDelegates()
    }

    func remakeSubscriptions() {
        clearAndSubscribeMetadata()
        subscribeBlockNumber()
    }

    func performDelegateSearch(accountId: AccountId) {
        let wrapper = identityOperationFactory.createIdentityWrapperByAccountId(
            for: { [accountId] },
            engine: connection,
            runtimeService: runtimeService,
            chainFormat: chain.chainFormat
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let identity = try wrapper.targetOperation.extractNoCancellableResultData().first?.value
                    self?.presenter?.didReceiveIdentity(identity, for: accountId)
                } catch {
                    self?.presenter?.didReceiveError(.delegateFetchFailed(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension GovernanceDelegateSearchInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            guard let blockNumber = blockNumber else {
                return
            }

            let optLastBlockNumber = currentBlockNumber
            currentBlockNumber = blockNumber

            if let lastBlockNumber = optLastBlockNumber, blockNumber.isNext(to: lastBlockNumber) {
                return
            }

            fetchDelegates()
        case let .failure(error):
            presenter?.didReceiveError(.blockSubscriptionFailed(error))
        }
    }
}
