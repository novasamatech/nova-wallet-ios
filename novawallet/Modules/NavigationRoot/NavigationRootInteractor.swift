import UIKit

final class NavigationRootInteractor {
    weak var presenter: NavigationRootInteractorOutputProtocol?
}

extension NavigationRootInteractor: NavigationRootInteractorInputProtocol {}
