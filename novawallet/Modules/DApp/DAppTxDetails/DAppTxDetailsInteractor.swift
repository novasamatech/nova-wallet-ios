import UIKit
import SubstrateSdk

final class DAppTxDetailsInteractor {
    weak var presenter: DAppTxDetailsInteractorOutputProtocol!

    let txDetails: JSON
    let preprocessor: JSONPrettyPrinting

    init(txDetails: JSON, preprocessor: JSONPrettyPrinting) {
        self.txDetails = txDetails
        self.preprocessor = preprocessor
    }
}

extension DAppTxDetailsInteractor: DAppTxDetailsInteractorInputProtocol {
    func setup() {
        do {
            let prettyPrintedJson = preprocessor.prettyPrinted(from: txDetails)

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(prettyPrintedJson)

            if let displayString = String(data: data, encoding: .utf8) {
                presenter.didReceive(displayResult: .success(displayString))
            } else {
                presenter.didReceive(displayResult: .failure(CommonError.undefined))
            }

        } catch {
            presenter.didReceive(displayResult: .failure(error))
        }
    }
}
