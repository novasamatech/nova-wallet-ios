import Foundation
import Foundation_iOS

struct DAppStakingNoticeViewFactory {
    static func createView(with delegate: DAppStakingNoticeDelegate) -> DAppStakingNoticeViewProtocol? {
        let wireframe = DAppStakingNoticeWireframe()
        wireframe.delegate = delegate

        let presenter = DAppStakingNoticePresenter(wireframe: wireframe)

        let view = DAppStakingNoticeViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
