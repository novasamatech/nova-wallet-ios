import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

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
                R.string.localizable.exportSeedTitle(preferredLanguages: locale.rLanguages)
            },
            exportSubtitle: LocalizableResource { locale in
                R.string.localizable.accountCreateDetails_v2_2_0(preferredLanguages: locale.rLanguages)
            },
            exportHint: LocalizableResource { locale in
                R.string.localizable.exportSeedHint(preferredLanguages: locale.rLanguages)
            },
            sourceTitle: LocalizableResource { locale in
                R.string.localizable.importRawSeed(preferredLanguages: locale.rLanguages)
            },
            sourceHint: LocalizableResource { locale in
                if chain.isEthereumBased {
                    return R.string.localizable.accountImportEthereumSeedPlaceholder_v2_2_0(
                        preferredLanguages: locale.rLanguages
                    )
                } else {
                    return R.string.localizable.accountImportSubstrateSeedPlaceholder_v2_2_0(
                        preferredLanguages: locale.rLanguages
                    )
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
