import Foundation

protocol WalletConnectSessionViewModelFactoryProtocol {
    func createViewModel(from model: WalletConnectSession) -> WalletConnectSessionViewModel
}

final class WalletConnectSessionViewModelFactory: WalletConnectSessionViewModelFactoryProtocol {
    let walletViewModelFactory = WalletAccountViewModelFactory()

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

        return .init(
            iconViewModel: iconViewModel,
            title: model.dAppName ?? "",
            wallet: walletViewModel,
            host: model.dAppHost ?? "",
            networks: .init(network: nil, supported: 0, unsupported: 0),
            status: model.active ? .active : .expired
        )
    }
}
