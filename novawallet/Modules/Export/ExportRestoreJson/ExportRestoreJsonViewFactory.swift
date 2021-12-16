import Foundation
import SoraFoundation

final class ExportRestoreJsonViewFactory: ExportRestoreJsonViewFactoryProtocol {
    static func createView(with model: RestoreJson) -> ExportGenericViewProtocol? {
        let wireframe = ExportRestoreJsonWireframe()
        let presenter = ExportRestoreJsonPresenter(wireframe: wireframe, model: model)

        let view = ExportGenericViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            exportTitle: LocalizableResource { locale in
                R.string.localizable.exportRestoreJsonTitle(preferredLanguages: locale.rLanguages)
            },
            exportSubtitle: nil,
            exportHint: nil,
            sourceTitle: LocalizableResource { locale in
                R.string.localizable.importRecoveryJson(preferredLanguages: locale.rLanguages)
            },
            sourceHint: nil,
            actionTitle: LocalizableResource { locale in
                R.string.localizable.accountExportAction(preferredLanguages: locale.rLanguages)
            },
            isSourceMultiline: false
        )

        presenter.view = view

        return view
    }
}
