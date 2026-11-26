import Foundation
import Foundation_iOS

struct DAppStakingNoticeViewFactory {
    static func createView(
        for context: DAppStakingNoticeContext,
        delegate: DAppStakingNoticeDelegate
    ) -> DAppStakingNoticeViewProtocol? {
        let wireframe = DAppStakingNoticeWireframe()
        wireframe.delegate = delegate

        let presenter = DAppStakingNoticePresenter(
            context: context,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = DAppStakingNoticeViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
