import UIKit

final class DAppOperationConfirmInteractor {
    weak var presenter: DAppOperationConfirmInteractorOutputProtocol?

    let request: DAppOperationRequest

    init(request: DAppOperationRequest) {
        self.request = request
    }
}

extension DAppOperationConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {}
