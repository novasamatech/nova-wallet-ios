import Foundation
import Keystore_iOS
import Foundation_iOS

enum ExportViewFactory {
    static func createView(
        with metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) -> ExportViewProtocol? {
        BaseExportViewFactory.createView(
            with: metaAccount,
            chain: chain,
            presenterType: ExportPresenter.self
        )
    }
}

enum AdvancedExportViewFactory {
    static func createView(
        with metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) -> ExportViewProtocol? {
        BaseExportViewFactory.createView(
            with: metaAccount,
            chain: chain,
            presenterType: AdvancedExportPresenter.self
        )
    }
}

private enum BaseExportViewFactory {
    static func createView<P: BaseExportPresenter>(
        with metaAccount: MetaAccountModel,
        chain: ChainModel?,
        presenterType _: P.Type
    ) -> ExportViewProtocol? {
        let keystore = Keychain()

        let interactor = ExportInteractor(keystore: keystore)
        let wireframe = ExportWireframe()

        let networkViewModelFactory = NetworkViewModelFactory()
        let advancedExportViewModelFactory = ExportViewModelFactory(
            networkViewModelFactory: networkViewModelFactory
        )

        let presenter = P(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared,
            viewModelFactory: advancedExportViewModelFactory,
            metaAccount: metaAccount,
            chain: chain
        )

        let view = ExportViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
