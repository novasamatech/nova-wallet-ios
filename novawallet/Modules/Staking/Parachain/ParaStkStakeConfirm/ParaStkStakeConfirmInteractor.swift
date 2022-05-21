import UIKit

final class ParaStkStakeConfirmInteractor {
    weak var presenter: ParaStkStakeConfirmInteractorOutputProtocol!
}

extension ParaStkStakeConfirmInteractor: ParaStkStakeConfirmInteractorInputProtocol {
    func setup() {}

    func estimateFee() {}

    func confirm() {}
}
