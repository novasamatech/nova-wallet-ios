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
            exportTitle: LocalizableResource { locale in
                R.string.localizable.accountBackupMnemonicTitle(preferredLanguages: locale.rLanguages)
            },
            exportSubtitle: LocalizableResource { locale in
                R.string.localizable.accountCreateDetails_v2_2_0(preferredLanguages: locale.rLanguages)
            },
            exportHint: LocalizableResource { locale in
                R.string.localizable.exportMnemonicCheckHint(preferredLanguages: locale.rLanguages)
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
