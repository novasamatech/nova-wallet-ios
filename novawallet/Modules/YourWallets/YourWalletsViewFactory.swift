import UIKit
import SubstrateSdk
import Foundation_iOS
import UIKit_iOS

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

        let maxHeight = ModalSheetPresentationConfiguration.maximumContentHeight
        let preferredContentSize = min(presenter.contentHeight, maxHeight)

        view.preferredContentSize = .init(
            width: 0,
            height: preferredContentSize
        )

        return view
    }
}
