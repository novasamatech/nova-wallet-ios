import Foundation

protocol WalletConnectSessionViewModelFactoryProtocol {
    func createViewModel(from model: WalletConnectSession) -> WalletConnectSessionViewModel
}

final class WalletConnectSessionViewModelFactory: WalletConnectSessionViewModelFactoryProtocol {
    let walletViewModelFactory = WalletAccountViewModelFactory()
    let networksViewModelFactory = WalletConnectNetworksViewModelFactory()

    func createViewModel(from model: WalletConnectSession) -> WalletConnectSessionViewModel {
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

        let networks = networksViewModelFactory.createViewModel(from: model.networks)

        return .init(
            iconViewModel: iconViewModel,
            title: model.dAppName ?? "",
            wallet: walletViewModel,
            host: model.dAppHost ?? "",
            networks: networks,
            status: model.active ? .active : .expired
        )
    }
}
