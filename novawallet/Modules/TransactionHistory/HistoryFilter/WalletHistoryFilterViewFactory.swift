import Foundation
import SoraFoundation
import CommonWallet

final class WalletHistoryFilterViewFactory: WalletHistoryFilterViewFactoryProtocol {
    // TODO: Remove
    static func createView(
        request _: WalletHistoryRequest,
        commandFactory _: WalletCommandFactoryProtocol,
        delegate _: HistoryFilterEditingDelegate?
    ) -> WalletHistoryFilterViewProtocol? {
        nil
    }

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
