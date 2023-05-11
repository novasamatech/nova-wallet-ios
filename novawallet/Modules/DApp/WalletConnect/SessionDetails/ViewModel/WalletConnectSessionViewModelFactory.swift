import Foundation

protocol WalletConnectSessionViewModelFactoryProtocol {
    func createViewModel(from model: WalletConnectSession) -> WalletConnectSessionViewModel
}

final class WalletConnectSessionViewModelFactory: WalletConnectSessionViewModelFactoryProtocol {
    let walletViewModelFactory = WalletAccountViewModelFactory()
    let networksViewModelFactory = DAppNetworksViewModelFactory()

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

        let resolution = DAppChainsResolution(wcResolution: model.networks)
        let networks = networksViewModelFactory.createViewModel(from: resolution)

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
