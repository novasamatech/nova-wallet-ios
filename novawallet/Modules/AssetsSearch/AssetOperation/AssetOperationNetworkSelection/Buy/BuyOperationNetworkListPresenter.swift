import Foundation

class BuyOperationNetworkListPresenter: AssetOperationNetworkListPresenter {
    override func provideTitle() {
        let title = R.string.localizable.buyOperationNetworkListTitle(
            multichainToken.symbol,
            preferredLanguages: selectedLocale.rLanguages
        )
        
        view?.updateHeader(with: title)
    }
}
