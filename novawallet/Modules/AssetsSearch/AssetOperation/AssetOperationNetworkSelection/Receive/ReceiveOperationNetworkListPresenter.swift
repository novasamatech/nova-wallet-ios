import Foundation

class ReceiveOperationNetworkListPresenter: AssetOperationNetworkListPresenter {
    override func provideTitle() {
        let title = R.string.localizable.receiveOperationNetworkListTitle(
            multichainToken.symbol,
            preferredLanguages: selectedLocale.rLanguages
        )
        
        view?.updateHeader(with: title)
    }
}
