import Foundation
import IrohaCrypto
import SoraFoundation

final class ExportMnemonicConfirmViewFactory: ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonic(_ mnemonic: IRMnemonicProtocol) -> AccountConfirmViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let presenter = AccountConfirmPresenter()

        let view = AccountConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )
//        view.nextButtonTitle = LocalizableResource { locale in
//            R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages)
//        }

        let interactor = ExportMnemonicConfirmInteractor(mnemonic: mnemonic)
        let wireframe = ExportMnemonicConfirmWireframe(localizationManager: localizationManager)

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        presenter.localizationManager = localizationManager

        return view
    }
}
