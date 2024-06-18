import Foundation

final class ExportPresenter: BaseExportPresenter {
    private let walletViewModelFactory = WalletAccountViewModelFactory()

    override func updateViewNavbar() {
        guard let walletViewModel = try? walletViewModelFactory.createDisplayViewModel(from: metaAccount) else {
            return
        }

        view?.updateNavbar(with: walletViewModel)
    }
}
