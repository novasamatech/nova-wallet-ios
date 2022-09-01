import Foundation
import SubstrateSdk
import SoraFoundation
import UIKit

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

        let maxHeight = UIScreen.main.bounds.height * 0.8
        let preferredContentSize = min(presenter.contentHeight + 20, maxHeight)

        view.preferredContentSize = .init(
            width: 0,
            height: preferredContentSize
        )

        return view
    }
}
