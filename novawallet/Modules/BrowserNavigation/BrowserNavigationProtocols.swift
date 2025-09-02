import Foundation
import Operation_iOS

protocol BrowserNavigationProviding {
    var browserNavigation: BrowserNavigationProtocol? { get }
}

protocol BrowserNavigationProtocol {
    func openBrowser(with dAppId: String)
    func openBrowser(with model: DAppNavigation)
    func openBrowser(with result: DAppSearchResult)
}

protocol BrowserNavigationInteractorInputProtocol {
    func setup()
}

protocol BrowserNavigationInteractorOutputProtocol: AnyObject {
    func didReceive(walletResult: Result<MetaAccountModel, Error>)
    func didReceive(dAppsResult: Result<DAppList, Error>?)
    func didReceiveFavoriteDapp(changes: [DataProviderChange<DAppFavorite>])
}
