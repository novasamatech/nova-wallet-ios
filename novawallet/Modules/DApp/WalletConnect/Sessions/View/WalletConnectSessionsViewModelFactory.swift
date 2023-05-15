import Foundation

protocol WalletConnectSessionsViewModelFactoryProtocol {
    func createViewModel(from model: WalletConnectSession) -> WalletConnectSessionListViewModel
}

final class WalletConnectSessionsViewModelFactory: WalletConnectSessionsViewModelFactoryProtocol {
    let walletViewModelFactory = WalletAccountViewModelFactory()

    func createViewModel(from model: WalletConnectSession) -> WalletConnectSessionListViewModel {
        let walletViewModel: DisplayWalletViewModel? = model.wallet.flatMap { wallet in
            try? walletViewModelFactory.createDisplayViewModel(from: wallet)
        }

        let iconViewModel: ImageViewModelProtocol

        if let icon = model.dAppIcon {
            iconViewModel = RemoteImageViewModel(url: icon)
        } else {
            let icon = R.image.iconDefaultDapp()!
            iconViewModel = StaticImageViewModel(image: icon)
        }

        return .init(
            identifier: model.sessionId,
            iconViewModel: iconViewModel,
            title: model.dAppName ?? model.dAppHost ?? "",
            wallet: walletViewModel
        )
    }
}
