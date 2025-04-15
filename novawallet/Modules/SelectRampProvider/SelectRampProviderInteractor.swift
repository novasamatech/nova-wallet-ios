import UIKit

final class SelectRampProviderInteractor {
    weak var presenter: SelectRampProviderInteractorOutputProtocol?
    let rampActions: [RampAction]

    init(rampActions: [RampAction]) {
        self.rampActions = rampActions
    }
}

// MARK: SelectRampProviderInteractorInputProtocol

extension SelectRampProviderInteractor: SelectRampProviderInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(rampActions)
    }
}
