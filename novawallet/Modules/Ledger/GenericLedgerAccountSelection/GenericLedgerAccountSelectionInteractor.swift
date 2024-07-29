import UIKit
import Operation_iOS
import SubstrateSdk

final class GenericLedgerAccountSelectionInteractor {
    weak var presenter: GenericLedgerAccountSelectionInteractorOutputProtocol?

    let requestFactory: StorageRequestFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let deviceId: UUID
    let ledgerApplication: GenericLedgerSubstrateApplicationProtocol
    let operationQueue: OperationQueue

    let cancellableStore = CancellableCallStore()

    init(
        chainRegistry: ChainRegistryProtocol,
        deviceId: UUID,
        ledgerApplication: GenericLedgerSubstrateApplicationProtocol,
        requestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.deviceId = deviceId
        self.requestFactory = requestFactory
        self.ledgerApplication = ledgerApplication
        self.operationQueue = operationQueue
    }

    deinit {
        cancellableStore.cancel()
    }

    private func subscribeLedgerChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: .allSatisfies([.enabledChains, .genericLedger])
        ) { [weak self] changes in
            self?.presenter?.didReceiveLedgerChain(changes: changes)
        }
    }

    private func createAccountBalanceWrapper(
        for chainAsset: ChainAsset,
        index: UInt32,
        runtimeProvider: RuntimeProviderProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<LedgerAccountAmount> {
        let chain = chainAsset.chain

        let queryFactory = WalletRemoteQueryWrapperFactory(
            requestFactory: requestFactory,
            assetInfoOperationFactory: AssetStorageInfoOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            ),
            runtimeProvider: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue
        )

        let accountFetchWrapper = ledgerApplication.getAccountWrapper(
            for: deviceId,
            index: index,
            addressPrefix: chain.addressPrefix,
            displayVerificationDialog: false
        )

        let balanceFetchWrapper: CompoundOperationWrapper<AssetBalance>
        balanceFetchWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let response = try accountFetchWrapper.targetOperation.extractNoCancellableResultData()
            let accountId = try response.account.address.toAccountId(using: chain.chainFormat)

            return queryFactory.queryBalance(for: accountId, chainAsset: chainAsset)
        }

        balanceFetchWrapper.addDependency(wrapper: accountFetchWrapper)

        let mappingOperation = ClosureOperation<LedgerAccountAmount> {
            let balance = try balanceFetchWrapper.targetOperation.extractNoCancellableResultData()
            let address = try accountFetchWrapper.targetOperation.extractNoCancellableResultData().account.address

            return LedgerAccountAmount(address: address, amount: balance.totalInPlank)
        }

        mappingOperation.addDependency(balanceFetchWrapper.targetOperation)

        return balanceFetchWrapper
            .insertingHead(operations: accountFetchWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }
}

extension GenericLedgerAccountSelectionInteractor: GenericLedgerAccountSelectionInteractorInputProtocol {
    func setup() {
        subscribeLedgerChains()
    }

    func loadBalance(for chainAsset: ChainAsset, at index: UInt32) {
        cancellableStore.cancel()

        let chain = chainAsset.chain

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            presenter?.didReceive(error: .accountBalanceFetch(ChainRegistryError.connectionUnavailable))
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            presenter?.didReceive(error: .accountBalanceFetch(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        let wrapper = createAccountBalanceWrapper(
            for: chainAsset,
            index: index,
            runtimeProvider: runtimeProvider,
            connection: connection
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(accountBalance):
                self?.presenter?.didReceive(accountBalance: accountBalance, at: index)
            case let .failure(error):
                self?.presenter?.didReceive(error: .accountBalanceFetch(error))
            }
        }
    }
}
