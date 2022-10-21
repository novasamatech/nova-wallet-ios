import UIKit
import SubstrateSdk
import RobinHood

final class DAppTxDetailsInteractor {
    weak var presenter: DAppTxDetailsInteractorOutputProtocol?

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

extension DAppTxDetailsInteractor: DAppTxDetailsInteractorInputProtocol {
    func setup() {
        let operation = prettyPrintedJSONOperationFactory.createProcessingOperation(for: txDetails)

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let displayString = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(displayResult: .success(displayString))
                } catch {
                    self?.presenter?.didReceive(displayResult: .failure(error))
                }
            }
        }

        operationQueue.addOperations([operation], waitUntilFinished: false)
    }
}
