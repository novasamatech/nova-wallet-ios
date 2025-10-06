import UIKit
import SubstrateSdk
import Operation_iOS

final class GovernanceDelegateSearchInteractor {
    weak var presenter: GovernanceDelegateSearchInteractorOutputProtocol?

    let delegateListOperationFactory: GovernanceDelegateListFactoryProtocol
    let lastVotedDays: Int
    let runtimeService: RuntimeProviderProtocol
    let metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let timelineService: ChainTimelineFacadeProtocol
    let chain: ChainModel
    let operationQueue: OperationQueue

    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private var currentBlockNumber: BlockNumber?

    init(
        delegateListOperationFactory: GovernanceDelegateListFactoryProtocol,
        lastVotedDays: Int,
        runtimeService: RuntimeProviderProtocol,
        metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        timelineService: ChainTimelineFacadeProtocol,
        chain: ChainModel,
        operationQueue: OperationQueue
    ) {
        self.delegateListOperationFactory = delegateListOperationFactory
        self.lastVotedDays = lastVotedDays
        self.runtimeService = runtimeService
        self.metadataProvider = metadataProvider
        self.identityProxyFactory = identityProxyFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.timelineService = timelineService
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
                timelineService: timelineService
            ),
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
        blockNumberSubscription = subscribeToBlockNumber(for: timelineService.timelineChainId)
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
        let wrapper = identityProxyFactory.createIdentityWrapperByAccountId(for: { [accountId] })

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
