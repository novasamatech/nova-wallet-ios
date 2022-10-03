import UIKit
import CommonWallet

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
}

protocol MainTabBarPresenterProtocol: AnyObject {
    func setup()
    func viewDidAppear()
}

protocol MainTabBarInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MainTabBarInteractorOutputProtocol: AnyObject {
    func didRequestImportAccount()
}

protocol MainTabBarWireframeProtocol: AlertPresentable, AuthorizationAccessible {
    func presentAccountImport(on view: MainTabBarViewProtocol?)
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView() -> MainTabBarViewProtocol?
}
