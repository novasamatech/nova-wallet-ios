import UIKit

final class NovaMainAppContainerInteractor {
    weak var presenter: NovaMainAppContainerInteractorOutputProtocol?
}

extension NovaMainAppContainerInteractor: NovaMainAppContainerInteractorInputProtocol {
    func setup() {}
}
