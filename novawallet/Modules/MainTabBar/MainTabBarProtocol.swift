import UIKit

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
    func didRequestScreenOpen(_ screen: UrlHandlingScreen)
}

protocol MainTabBarWireframeProtocol: AlertPresentable, AuthorizationAccessible {
    func presentAccountImport(on view: MainTabBarViewProtocol?)
    func presentScreenIfNeeded(on view: MainTabBarViewProtocol?, screen: UrlHandlingScreen)
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView() -> MainTabBarViewProtocol?
}
