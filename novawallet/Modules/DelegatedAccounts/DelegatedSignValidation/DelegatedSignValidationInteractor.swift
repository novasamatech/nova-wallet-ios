import UIKit

final class DelegatedSignValidationInteractor {
    weak var presenter: DelegatedSignValidationInteractorOutputProtocol?
}

extension DelegatedSignValidationInteractor: DelegatedSignValidationInteractorInputProtocol {
    func setup() {}
}
