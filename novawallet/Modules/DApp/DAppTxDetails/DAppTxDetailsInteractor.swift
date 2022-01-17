import UIKit
import SubstrateSdk
import RobinHood

final class DAppTxDetailsInteractor {
    weak var presenter: DAppTxDetailsInteractorOutputProtocol?

    let txDetails: JSON
    let preprocessor: JSONPrettyPrinting
    let operationQueue: OperationQueue

    init(txDetails: JSON, preprocessor: JSONPrettyPrinting, operationQueue: OperationQueue) {
        self.txDetails = txDetails
        self.preprocessor = preprocessor
        self.operationQueue = operationQueue
    }

    private func createProcessingOperation(
        for details: JSON,
        preprocessor: JSONPrettyPrinting
    ) -> BaseOperation<String> {
        ClosureOperation<String> {
            let prettyPrintedJson = preprocessor.prettyPrinted(from: details)

            if case let .stringValue(value) = prettyPrintedJson {
                return value
            } else {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted

                let data = try encoder.encode(prettyPrintedJson)

                if let displayString = String(data: data, encoding: .utf8) {
                    return displayString
                } else {
                    throw CommonError.undefined
                }
            }
        }
    }
}

extension DAppTxDetailsInteractor: DAppTxDetailsInteractorInputProtocol {
    func setup() {
        let operation = createProcessingOperation(for: txDetails, preprocessor: preprocessor)

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
