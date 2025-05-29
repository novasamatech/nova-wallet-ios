import UIKit
import Operation_iOS
import SubstrateSdk

final class GenericLedgerAccountSelectionInteractor {
    weak var presenter: GenericLedgerAccountSelectionInteractorOutputProtocol?

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
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.deviceId = deviceId
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

    private func createSubstrateAccountWrapper(at index: UInt32) -> CompoundOperationWrapper<AccountAddress> {
        let fetchWrapper = ledgerApplication.getGenericSubstrateAccountWrapper(
            for: deviceId,
            index: index,
            addressPrefix: SubstrateConstants.genericAddressPrefix,
            displayVerificationDialog: false
        )

        let mappingOperation = ClosureOperation<AccountAddress> {
            let response = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            return response.account.address
        }

        mappingOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper.insertingTail(operation: mappingOperation)
    }

    private func createEvmAccountWrapper(at index: UInt32) -> CompoundOperationWrapper<AccountAddress> {
        let fetchWrapper = ledgerApplication.getGenericEvmAccountWrapper(
            for: deviceId,
            index: index,
            displayVerificationDialog: false
        )

        let mappingOperation = ClosureOperation<AccountAddress> {
            let response = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            return response.account.address
        }

        mappingOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper.insertingTail(operation: mappingOperation)
    }

    private func createAccountWrapper(
        at index: UInt32,
        scheme: HardwareWalletAddressScheme
    ) -> CompoundOperationWrapper<AccountAddress> {
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

    func loadAccounts(at index: UInt32, schemes: Set<HardwareWalletAddressScheme>) {
        cancellableStore.cancel()

        let wrappers = schemes.map { scheme in
            createAccountWrapper(at: index, scheme: scheme)
        }

        for (wrapperIndex, wrapper) in wrappers.enumerated() where wrapperIndex > 0 {
            wrapper.addDependency(wrapper: wrappers[wrapperIndex - 1])
        }

        let mappingOperation = ClosureOperation<GenericLedgerAccountModel> {
            let addresses = try zip(schemes, wrappers).map { scheme, wrapper in
                let address = try wrapper.targetOperation.extractNoCancellableResultData()

                return HardwareWalletAddressModel(address: address, scheme: scheme)
            }

            return GenericLedgerAccountModel(index: index, addresses: addresses.sortedBySchemeOrder())
        }

        let dependencies = wrappers.flatMap(\.allOperations)

        wrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

        let totalWrapper = CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.presenter?.didReceive(account: model)
            case let .failure(error):
                self?.logger.error("Unexpected Ledger account fetch error \(error)")
            }
        }
    }
}
