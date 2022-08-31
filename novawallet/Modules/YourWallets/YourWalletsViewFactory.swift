import Foundation
import SubstrateSdk
import SoraFoundation

struct YourWalletsViewFactory {
    static func createView(
        metaAccounts: [MetaAccountChainResponse],
        address: AccountAddress?,
        delegate: YourWalletsDelegate
    ) -> YourWalletsViewProtocol? {
        let presenter = YourWalletsPresenter(
            localizationManager: LocalizationManager.shared,
            accountIconGenerator: NovaIconGenerator(),
            chainIconGenerator: PolkadotIconGenerator(),
            metaAccounts: metaAccounts,
            selectedAddress: address,
            delegate: delegate
        )

        let view = YourWalletsViewController(
            presenter: presenter
        )
        presenter.view = view

        view.preferredContentSize = .init(width: 0, height: presenter.contentHeight)

        return view
    }
}
