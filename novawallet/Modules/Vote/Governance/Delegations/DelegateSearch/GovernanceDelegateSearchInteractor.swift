import UIKit
import SubstrateSdk
import RobinHood

final class GovernanceDelegateSearchInteractor {
    weak var presenter: GovernanceDelegateSearchInteractorOutputProtocol?

    let delegateListOperationFactory: GovernanceDelegateListFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeProviderProtocol
    let metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let chain: ChainModel
    let operationQueue: OperationQueue

    init(
        delegateListOperationFactory: GovernanceDelegateListFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        chain: ChainModel,
        operationQueue: OperationQueue
    ) {
        self.delegateListOperationFactory = delegateListOperationFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.metadataProvider = metadataProvider
        self.identityOperationFactory = identityOperationFactory
        self.chain = chain
        self.operationQueue = operationQueue
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
    }

    func refreshDelegates() {}

    func remakeSubscriptions() {
        clearAndSubscribeMetadata()
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
