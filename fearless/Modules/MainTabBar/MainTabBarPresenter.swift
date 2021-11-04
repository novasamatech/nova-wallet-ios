import Foundation

final class MainTabBarPresenter {
    weak var view: MainTabBarViewProtocol?
    var interactor: MainTabBarInteractorInputProtocol!
    var wireframe: MainTabBarWireframeProtocol!
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func viewDidAppear() {}
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didReloadSelectedAccount() {
        wireframe.showNewWalletView(on: view)
        wireframe.showNewCrowdloan(on: view)
    }

    func didRequestImportAccount() {
        wireframe.presentAccountImport(on: view)
    }
}
