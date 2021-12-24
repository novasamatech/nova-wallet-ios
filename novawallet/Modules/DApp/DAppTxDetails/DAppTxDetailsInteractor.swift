import UIKit
import SubstrateSdk

final class DAppTxDetailsInteractor {
    weak var presenter: DAppTxDetailsInteractorOutputProtocol!

    let txDetails: JSON

    init(txDetails: JSON) {
        self.txDetails = txDetails
    }
}

extension DAppTxDetailsInteractor: DAppTxDetailsInteractorInputProtocol {
    func setup() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(txDetails)

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
