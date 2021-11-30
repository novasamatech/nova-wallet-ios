import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class ExportMnemonicViewFactory {
    static func createViewForMetaAccount(
        _ metaAccount: MetaAccountModel,
        chain: ChainModel
    ) -> ExportGenericViewProtocol? {
        let keychain = Keychain()

        let interactor = ExportMnemonicInteractor(
            metaAccount: metaAccount,
            chain: chain,
            keystore: keychain,
            operationManager: OperationManagerFacade.sharedManager
        )

        let wireframe = ExportMnemonicWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = ExportMnemonicPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager
        )

        let view = ExportGenericViewController(
            presenter: presenter,
            localizationManager: localizationManager,
            exportTitle: LocalizableResource { _ in
                "Write down the phrase and store it in a safe place"
            },
            exportSubtitle: LocalizableResource { locale in
                R.string.localizable.accountCreateDetails(preferredLanguages: locale.rLanguages)
            },
            exportHint: LocalizableResource { _ in
                "Please, make sure to write down your phrase correctly and legibly."
            },
            sourceTitle: LocalizableResource { locale in
                R.string.localizable.importMnemonic(preferredLanguages: locale.rLanguages)
            },
            sourceHint: nil,
            actionTitle: LocalizableResource { locale in
                R.string.localizable.accountConfirmationTitle(preferredLanguages: locale.rLanguages)
            },
            isSourceMultiline: true
        )

        presenter.view = view
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
