import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class ExportMnemonicViewFactory {
    static func createViewForMetaAccount(
        _ metaAccount: MetaAccountModel,
        chain: ChainModel
    ) -> ExportGenericViewProtocol? {
        let accessoryActionTitle = LocalizableResource { locale in
            R.string.localizable.accountConfirmationTitle(preferredLanguages: locale.rLanguages)
        }

        let uiFactory = UIFactory()
        let view = ExportGenericViewController(
            uiFactory: uiFactory,
            binder: ExportGenericViewModelBinder(uiFactory: uiFactory),
            mainTitle: nil,
            accessoryTitle: accessoryActionTitle
        )

        let localizationManager = LocalizationManager.shared

        let presenter = ExportMnemonicPresenter(
            localizationManager: localizationManager
        )

        let keychain = Keychain()

        let interactor = ExportMnemonicInteractor(
            metaAccount: metaAccount,
            chain: chain,
            keystore: keychain,
            operationManager: OperationManagerFacade.sharedManager
        )
        let wireframe = ExportMnemonicWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
