import Foundation
import IrohaCrypto
import SoraFoundation

final class ExportMnemonicConfirmViewFactory: ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonic(_ mnemonic: IRMnemonicProtocol) -> AccountConfirmViewProtocol? {
        let localizationManager = LocalizationManager.shared
        var showsSkipButton = false

        #if F_DEV
            showsSkipButton = true
        #endif

        let interactor = ExportMnemonicConfirmInteractor(mnemonic: mnemonic)
        let wireframe = ExportMnemonicConfirmWireframe(localizationManager: localizationManager)
        let mnemonicViewModelFactory = MnemonicViewModelFactory(localizationManager: localizationManager)

        let presenter = AccountConfirmPresenter(
            wireframe: wireframe,
            interactor: interactor,
            mnemonicViewModelFactory: mnemonicViewModelFactory,
            localizationManager: localizationManager
        )

        let view = AccountConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager,
            showsSkipButton: showsSkipButton
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
