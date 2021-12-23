import UIKit

final class DAppSearchInteractor {
    weak var presenter: DAppSearchInteractorOutputProtocol!
}

extension DAppSearchInteractor: DAppSearchInteractorInputProtocol {}
