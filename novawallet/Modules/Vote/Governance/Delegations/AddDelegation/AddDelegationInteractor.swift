import UIKit

final class AddDelegationInteractor {
    weak var presenter: AddDelegationInteractorOutputProtocol!
}

extension AddDelegationInteractor: AddDelegationInteractorInputProtocol {}
