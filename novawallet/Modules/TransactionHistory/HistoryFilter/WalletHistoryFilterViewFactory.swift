import Foundation
import SoraFoundation

final class WalletHistoryFilterViewFactory {
    static func createView(
        filter: WalletHistoryFilter,
        delegate: TransactionHistoryFilterEditingDelegate?
    ) -> WalletHistoryFilterViewProtocol? {
        let presenter = WalletHistoryFilterPresenter(filter: filter)
        let view = WalletHistoryFilterViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let wireframe = WalletHistoryFilterWireframe(
            delegate: delegate
        )

        presenter.view = view
        presenter.wireframe = wireframe

        return view
    }
}
