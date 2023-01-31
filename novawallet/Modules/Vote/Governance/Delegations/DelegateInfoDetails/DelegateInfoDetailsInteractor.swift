import UIKit

final class DelegateInfoDetailsInteractor {
    weak var presenter: DelegateInfoDetailsInteractorOutputProtocol!
}

extension DelegateInfoDetailsInteractor: DelegateInfoDetailsInteractorInputProtocol {}