import UIKit
import Operation_iOS

final class GenericLedgerWalletInteractor {
    weak var presenter: GenericLedgerWalletInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let deviceId: UUID
    let ledgerApplication: GenericLedgerPolkadotApplicationProtocol
    let index: UInt32
    let supportsEvmAddresses: Bool
    let operationQueue: OperationQueue

    init(
        ledgerApplication: GenericLedgerPolkadotApplicationProtocol,
        deviceId: UUID,
        index: UInt32,
        supportsEvmAddresses: Bool,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.deviceId = deviceId
        self.ledgerApplication = ledgerApplication
        self.index = index
        self.supportsEvmAddresses = supportsEvmAddresses
        self.operationQueue = operationQueue
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            let actualChanges: [DataProviderChange<ChainModel>] = changes.compactMap { change in
                switch change {
                case let .insert(item):
                    return item.supportsGenericLedgerApp ? .insert(newItem: item) : nil
                case let .update(item):
                    return item.supportsGenericLedgerApp ?
                        .update(newItem: item) :
                        .delete(deletedIdentifier: item.identifier)
                case let .delete(identifier):
                    return .delete(deletedIdentifier: identifier)
                }
            }

            self?.presenter?.didReceiveChains(changes: actualChanges)
        }
    }
}

extension GenericLedgerWalletInteractor: GenericLedgerWalletInteractorInputProtocol {
    func setup() {
        subscribeChains()
        fetchAccount()
    }

    func fetchAccount() {
        let wrapper = ledgerApplication.getGenericSubstrateAccountWrapperBy(deviceId: deviceId, index: index)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(response):
                self?.presenter?.didReceive(account: response.account)
            case let .failure(error):
                self?.presenter?.didReceive(error: .fetAccount(error))
            }
        }
    }

    func confirmAccount() {
        let substrateWrapper = ledgerApplication.getGenericSubstrateAccountWrapperBy(
            deviceId: deviceId,
            index: index,
            displayVerificationDialog: true
        )

        let evmWrapper: CompoundOperationWrapper<LedgerEvmAccountResponse>? = if supportsEvmAddresses {
            ledgerApplication.getGenericEvmAccountWrapper(
                for: deviceId,
                index: index,
                displayVerificationDialog: true
            )
        } else {
            nil
        }

        evmWrapper?.addDependency(wrapper: substrateWrapper)

        let mappingOperation = ClosureOperation<PolkadotLedgerWalletModel> {
            let substrateModel = try substrateWrapper.targetOperation.extractNoCancellableResultData()
            let evmModel = try evmWrapper?.targetOperation.extractNoCancellableResultData()

            let substrateAccountId = try substrateModel.account.address.toAccountId()

            let substrate = PolkadotLedgerWalletModel.Substrate(
                accountId: substrateAccountId,
                publicKey: substrateModel.account.publicKey,
                cryptoType: LedgerConstants.defaultSubstrateCryptoScheme.walletCryptoType,
                derivationPath: substrateModel.derivationPath
            )

            let evm = evmModel.map {
                PolkadotLedgerWalletModel.EVM(
                    publicKey: $0.account.publicKey,
                    derivationPath: $0.derivationPath
                )
            }

            return PolkadotLedgerWalletModel(substrate: substrate, evm: evm)
        }

        mappingOperation.addDependency(substrateWrapper.targetOperation)

        if let evmWrapper {
            mappingOperation.addDependency(evmWrapper.targetOperation)
        }

        let totalWrapper = substrateWrapper
            .insertingHead(operations: evmWrapper?.allOperations ?? [])
            .insertingTail(operation: mappingOperation)

        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(response):
                self?.presenter?.didReceiveAccountConfirmation(with: response)
            case let .failure(error):
                self?.presenter?.didReceive(error: .confirmAccount(error))
            }
        }
    }

    func cancelRequest() {
        ledgerApplication.connectionManager.cancelRequest(for: deviceId)
    }
}
