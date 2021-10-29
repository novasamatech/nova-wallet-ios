import Foundation

final class UsernameSetupInteractor {
    weak var presenter: UsernameSetupInteractorOutputProtocol!
}

extension UsernameSetupInteractor: UsernameSetupInteractorInputProtocol {
    func setup() {}
}
