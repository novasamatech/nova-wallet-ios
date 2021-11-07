import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

final class ExportSeedViewFactory {
    static func createViewForMetaAccount(
        _ metaAccount: MetaAccountModel,
        chain: ChainModel
    ) -> ExportGenericViewProtocol? {
        let uiFactory = UIFactory()
        let view = ExportGenericViewController(
            uiFactory: uiFactory,
            binder: ExportGenericViewModelBinder(uiFactory: uiFactory),
            mainTitle: nil,
            accessoryTitle: nil
        )

        let localizationManager = LocalizationManager.shared

        let presenter = ExportSeedPresenter(
            localizationManager: localizationManager
        )

        let keychain = Keychain()

        let interactor = ExportSeedInteractor(
            metaAccount: metaAccount,
            chain: chain,
            keystore: keychain,
            operationManager: OperationManagerFacade.sharedManager
        )
        let wireframe = ExportSeedWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
