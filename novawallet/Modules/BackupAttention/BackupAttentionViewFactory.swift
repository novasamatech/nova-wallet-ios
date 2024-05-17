import Foundation
import SoraFoundation
import SoraUI

struct BackupAttentionViewFactory {
    static func createView(with metaAccount: MetaAccountModel) -> BackupAttentionViewProtocol? {
        let wireframe = BackupAttentionWireframe(metaAccount: metaAccount)

        let presenter = BackupAttentionPresenter(
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let appearanceAnimator = FadeAnimator(
            from: 0.0,
            to: 1.0,
            duration: 0.2,
            delay: 0.0,
            options: .curveEaseInOut
        )

        let disappearanceAnimator = FadeAnimator(
            from: 1.0,
            to: 0.0,
            duration: 0.15,
            delay: 0.0,
            options: .curveEaseInOut
        )

        let view = BackupAttentionViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            appearanceAnimator: appearanceAnimator,
            disappearanceAnimator: disappearanceAnimator
        )

        presenter.view = view

        return view
    }
}
