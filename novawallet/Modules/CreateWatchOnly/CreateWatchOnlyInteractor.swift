import UIKit

final class CreateWatchOnlyInteractor {
    weak var presenter: CreateWatchOnlyInteractorOutputProtocol!
}

extension CreateWatchOnlyInteractor: CreateWatchOnlyInteractorInputProtocol {}
