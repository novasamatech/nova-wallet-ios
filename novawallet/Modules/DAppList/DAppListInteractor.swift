import UIKit

final class DAppListInteractor {
    weak var presenter: DAppListInteractorOutputProtocol!
}

extension DAppListInteractor: DAppListInteractorInputProtocol {}