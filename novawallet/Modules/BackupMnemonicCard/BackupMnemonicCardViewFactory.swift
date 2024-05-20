import Foundation
import SoraKeystore
import SoraFoundation
import SoraUI

struct BackupMnemonicCardViewFactory {
    static func createView(with metaAccount: MetaAccountModel) -> BackupMnemonicCardViewProtocol? {
        let keychain = Keychain()

        let interactor = BackupMnemonicCardInteractor(
            metaAccount: metaAccount,
            keystore: keychain,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = BackupMnemonicCardWireframe()

        let presenter = BackupMnemonicCardPresenter(
            interactor: interactor,
            wireframe: wireframe,
            metaAccount: metaAccount,
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

        let view = BackupMnemonicCardViewController(
            presenter: presenter,
            appearanceAnimator: appearanceAnimator,
            disappearanceAnimator: disappearanceAnimator,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
