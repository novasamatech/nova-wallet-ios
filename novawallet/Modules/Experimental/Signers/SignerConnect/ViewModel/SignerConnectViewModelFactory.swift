import Foundation
import SubstrateSdk

protocol SignerConnectViewModelFactoryProtocol {
    func createViewModel(
        from metadata: BeaconConnectionInfo,
        wallet: MetaAccountModel
    ) throws -> SignerConnectViewModel
}

final class SignerConnectViewModelFactory: SignerConnectViewModelFactoryProtocol {
    func createViewModel(
        from metadata: BeaconConnectionInfo,
        wallet: MetaAccountModel
    ) throws -> SignerConnectViewModel {
        let iconViewModel = createImageViewModel(from: metadata.icon)

        let accountIcon = try NovaIconGenerator().generateFromAccountId(
            wallet.substrateAccountId
        )

        let host: String? = {
            guard let appUrl = metadata.appUrl else {
                return nil
            }

            return URL(string: appUrl)?.host
        }()

        return SignerConnectViewModel(
            title: metadata.name,
            icon: iconViewModel,
            connection: host ?? metadata.relayServer,
            accountName: wallet.name,
            accountIcon: accountIcon
        )
    }

    private func createImageViewModel(from icon: String?) -> ImageViewModelProtocol? {
        let defaultIconClosure: () -> ImageViewModelProtocol? = {
            let defaultIcon = R.image.iconDefaultDapp()
            return defaultIcon.map { WalletStaticImageViewModel(staticImage: $0) }
        }

        guard let iconString = icon else {
            return defaultIconClosure()
        }

        if let url = URL(string: iconString) {
            return RemoteImageViewModel(url: url)
        }

        if let data = Data(base64Encoded: iconString), let image = UIImage(data: data) {
            return WalletStaticImageViewModel(staticImage: image)
        }

        return defaultIconClosure()
    }
}
