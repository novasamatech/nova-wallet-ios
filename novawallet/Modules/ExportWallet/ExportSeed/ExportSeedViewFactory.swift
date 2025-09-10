import Foundation
import Keystore_iOS
import Operation_iOS
import Foundation_iOS

final class ExportSeedViewFactory {
    static func createViewForMetaAccount(
        _ metaAccount: MetaAccountModel,
        chain: ChainModel
    ) -> ExportGenericViewProtocol? {
        let keychain = Keychain()

        let interactor = ExportSeedInteractor(
            metaAccount: metaAccount,
            chain: chain,
            keystore: keychain,
            operationManager: OperationManagerFacade.sharedManager
        )

        let wireframe = ExportSeedWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = ExportSeedPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager
        )

        let view = ExportGenericViewController(
            presenter: presenter,
            localizationManager: localizationManager,
            exportTitle: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.exportSeedTitle()
            },
            exportSubtitle: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.accountCreateDetails_v2_2_0()
            },
            exportHint: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.exportSeedHint()
            },
            sourceTitle: LocalizableResource { locale in
                if chain.isEthereumBased {
                    return R.string(preferredLanguages: locale.rLanguages).localizable.secretTypePrivateKeyTitle()
                } else {
                    return R.string(preferredLanguages: locale.rLanguages).localizable.importRawSeed()
                }
            },
            sourceHint: LocalizableResource { locale in
                if chain.isEthereumBased {
                    return R.string(preferredLanguages: locale.rLanguages).localizable.accountExportEthereumPrivateKeyPlaceholder()
                } else {
                    return R.string(preferredLanguages: locale.rLanguages).localizable.accountImportSubstrateSeedPlaceholder_v2_2_0()
                }
            },
            actionTitle: nil,
            isSourceMultiline: true
        )

        presenter.view = view
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
