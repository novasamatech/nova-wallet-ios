import Foundation
import SoraFoundation

struct DAppSettingsViewFactory {
    static func createView(
        state: DAppSettingsInput,
        delegate: DAppSettingsDelegate
    ) -> DAppSettingsViewProtocol? {
        let presenter = DAppSettingsPresenter(
            state: state,
            delegate: delegate,
            localizationManager: LocalizationManager.shared
        )

        let view = DAppSettingsViewController(presenter: presenter)
        view.preferredContentSize = .init(
            width: 0,
            height: 196
        )

        presenter.view = view
        return view
    }
}
