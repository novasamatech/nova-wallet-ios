import Foundation

struct AdvancedWalletViewFactory {
    static func createView() -> AdvancedWalletViewProtocol? {
        let wireframe = AdvancedWalletWireframe()

        let settings = AdvancedWalletSettings.ethereum(
            settings: AdvancedNetworkTypeSettings(cryptoType: .sr25519, derivationPath: nil)
        )
        let presenter = AdvancedWalletPresenter(wireframe: wireframe, settings: settings)

        let view = AdvancedWalletViewController(presenter: presenter)

        presenter.view = view

        return view
    }
}
