import UIKit
import Operation_iOS
import SubstrateSdk

final class GenericLedgerAccountSelectionInteractor {
    weak var presenter: GenericLedgerAccountSelectionInteractorOutputProtocol?

    let requestFactory: StorageRequestFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let deviceId: UUID
    let ledgerApplication: GenericLedgerPolkadotApplicationProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    let cancellableStore = CancellableCallStore()

    init(
        chainRegistry: ChainRegistryProtocol,
        deviceId: UUID,
        ledgerApplication: GenericLedgerPolkadotApplicationProtocol,
        requestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.deviceId = deviceId
        self.requestFactory = requestFactory
        self.ledgerApplication = ledgerApplication
        self.operationQueue = operationQueue
        self.logger = logger
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
    
    private func createSubstrateAccountWrapper(at index: UInt32) -> CompoundOperationWrapper<GenericLedgerAddressModel> {
        let fetchWrapper = ledgerApplication.getGenericSubstrateAccountWrapper(
            for: deviceId,
            index: index,
            addressPrefix: SubstrateConstants.genericAddressPrefix,
            displayVerificationDialog: false
        )
        
        let mappingOperation = ClosureOperation<GenericLedgerAddressModel> {
            let response = try fetchWrapper.targetOperation.extractNoCancellableResultData()
            
            return GenericLedgerAddressModel(
                address: response.account.address,
                type: .substrate
            )
        }
        
        mappingOperation.addDependency(fetchWrapper.targetOperation)
        
        return fetchWrapper.insertingTail(operation: mappingOperation)
    }
    
    private func createEvmAccountWrapper(at index: UInt32) -> CompoundOperationWrapper<GenericLedgerAddressModel> {
        let fetchWrapper = ledgerApplication.getGenericEvmAccountWrapper(
            for: deviceId,
            index: index,
            displayVerificationDialog: false
        )
        
        let mappingOperation = ClosureOperation<GenericLedgerAddressModel> {
            let response = try fetchWrapper.targetOperation.extractNoCancellableResultData()
            
            return GenericLedgerAddressModel(
                address: response.account.address,
                type: .substrate
            )
        }
        
        mappingOperation.addDependency(fetchWrapper.targetOperation)
        
        return fetchWrapper.insertingTail(operation: mappingOperation)
    }

    private func createAccountWrapper(
        at index: UInt32,
        scheme: GenericLedgerAddressScheme
    ) -> CompoundOperationWrapper<GenericLedgerAddressModel> {
        switch scheme {
        case .substrate:
            createSubstrateAccountWrapper(at: index)
        case .evm:
            createEvmAccountWrapper(at: index)
        }
    }
}

extension GenericLedgerAccountSelectionInteractor: GenericLedgerAccountSelectionInteractorInputProtocol {
    func setup() {
        subscribeLedgerChains()
    }

    func loadAccounts(at index: UInt32, schemes: Set<GenericLedgerAddressScheme>) {
        cancellableStore.cancel()

        let wrappers = schemes.map { scheme in
            createAccountWrapper(at: index, scheme: scheme)
        }
        
        for (wrapperIndex, wrapper) in wrappers.enumerated() {
            if wrapperIndex > 0 {
                wrapper.addDependency(wrapper: wrappers[wrapperIndex - 1])
            }
        }
        
        let mappingOperation = ClosureOperation<GenericLedgerIndexedAccountModel> {
            let accounts = zip(schemes, wrappers).map { scheme, wrapper in
                do {
                    return try wrapper.targetOperation.extractNoCancellableResultData()
                } catch {
                    return GenericLedgerAddressModel(result: .fetchFailed(error), type: scheme)
                }
            }
            
            return GenericLedgerIndexedAccountModel(index: index, accounts: accounts)
        }
        
        let dependencies = wrappers.flatMap { $0.allOperations }
        
        wrappers.forEach { mappingOperation.targetOperation.addDependency($0.targetOperation) }
        
        let totalWrapper = CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.presenter?.didReceive(indexedAccount: model)
            case let .failure(error):
                self?.logger.error("Unexpected Ledger account fetch error \(error)")
            }
        }
    }
}
