import Foundation
import Foundation_iOS

struct DAppStakingWarningViewFactory {
    static func createView(
        for url: URL,
        delegate: DAppStakingWarningViewDelegate
    ) -> DAppStakingWarningViewProtocol? {
        let wireframe = DAppStakingWarningWireframe(delegate: delegate, blockedURL: url)

        let presenter = DAppStakingWarningPresenter(wireframe: wireframe)

        let view = DAppStakingWarningViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
