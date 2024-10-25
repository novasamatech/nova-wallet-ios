import Foundation

class SendOperationNetworkListPresenter: AssetOperationNetworkListPresenter {
    override func provideTitle() {
        let title = R.string.localizable.sendOperationNetworkListTitle(
            multichainToken.symbol,
            preferredLanguages: selectedLocale.rLanguages
        )

        view?.updateHeader(with: title)
    }
}
