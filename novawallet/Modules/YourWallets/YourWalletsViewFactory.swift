import Foundation
import SubstrateSdk
import SoraFoundation

struct YourWalletsViewFactory {
    static func createView(
        metaAccounts: [PossibleMetaAccountChainResponse],
        address: AccountAddress?,
        delegate: YourWalletsDelegate
    ) -> YourWalletsViewProtocol? {
        let wireframe = YourWalletsWireframe()

        let presenter = YourWalletsPresenter(
            wireframe: wireframe,
            iconGenerator: NovaIconGenerator(),
            metaAccounts: metaAccounts,
            selectedAddress: address,
            delegate: delegate
        )

        let view = YourWalletsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view

        return view
    }
}
