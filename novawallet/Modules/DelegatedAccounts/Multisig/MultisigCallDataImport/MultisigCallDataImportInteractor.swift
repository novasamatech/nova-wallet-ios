import Foundation
import Operation_iOS

final class MultisigCallDataImportInteractor {
    weak var presenter: MultisigCallDataImportInteractorOutputProtocol?

    private let pendingOperation: Multisig.PendingOperation
    private let pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>
    private let operationQueue: OperationQueue

    init(
        pendingOperation: Multisig.PendingOperation,
        pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>,
        operationQueue: OperationQueue
    ) {
        self.pendingOperation = pendingOperation
        self.pendingOperationsRepository = pendingOperationsRepository
        self.operationQueue = operationQueue
    }
}

// MARK: - MultisigCallDataImportInteractorInputProtocol

extension MultisigCallDataImportInteractor: MultisigCallDataImportInteractorInputProtocol {
    func importCallData(_ callDataString: String) {
        guard
            let callData = try? Substrate.CallData(hexString: callDataString),
            let callHash = try? callData.blake2b32()
        else {
            presenter?.didReceive(importResult: .failure(MultisigCallDataImportError.invalidCallData))
            return
        }

        guard callHash == pendingOperation.callHash else {
            presenter?.didReceive(
                importResult: .failure(
                    MultisigCallDataImportError.differentHash(hash: callHash.toHexWithPrefix())
                )
            )
            return
        }

        let saveOperation = pendingOperationsRepository.saveOperation(
            { [self.pendingOperation.replacingCall(with: callData)] },
            { [] }
        )

        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] in self?.presenter?.didReceive(importResult: $0) }
    }
}

enum MultisigCallDataImportError: Error {
    case invalidCallData
    case differentHash(hash: String)
}
