import UIKit
import SubstrateSdk
import Operation_iOS

final class MultisigTxDetailsInteractor {
    weak var presenter: MultisigTxDetailsInteractorOutputProtocol?

    let txDetails: JSON
    let prettyPrintedJSONOperationFactory: PrettyPrintedJSONOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        txDetails: JSON,
        prettyPrintedJSONOperationFactory: PrettyPrintedJSONOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.txDetails = txDetails
        self.prettyPrintedJSONOperationFactory = prettyPrintedJSONOperationFactory
        self.operationQueue = operationQueue
    }
}

extension MultisigTxDetailsInteractor: MultisigTxDetailsInteractorInputProtocol {
    func setup() {
        let operation = prettyPrintedJSONOperationFactory.createProcessingOperation(for: txDetails)

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in

            switch result {
            case let .success(displayString):
                self?.presenter?.didReceive(displayResult: .success(displayString))
            case let .failure(error):
                self?.presenter?.didReceive(displayResult: .failure(error))
            }
        }
    }
}
