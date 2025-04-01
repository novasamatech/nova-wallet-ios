import Foundation
import NovaCrypto
import Foundation_iOS

final class ExportMnemonicConfirmViewFactory: ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonic(_ mnemonic: IRMnemonicProtocol) -> AccountConfirmViewProtocol? {
        let localizationManager = LocalizationManager.shared

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
            showsSkipButton: false
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
