import Foundation
import SoraFoundation

final class ExportSeedPresenter {
    weak var view: ExportGenericViewProtocol?
    let wireframe: ExportSeedWireframeProtocol
    let interactor: ExportSeedInteractorInputProtocol
    let localizationManager: LocalizationManager

    private(set) var exportData: ExportSeedData?

    init(
        interactor: ExportSeedInteractorInputProtocol,
        wireframe: ExportSeedWireframeProtocol,
        localizationManager: LocalizationManager
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }
}

extension ExportSeedPresenter: ExportGenericPresenterProtocol {
    func setup() {
        interactor.fetchExportData()
    }

    func activateExport() {}

    func activateAdvancedSettings() {}
}

extension ExportSeedPresenter: ExportSeedInteractorOutputProtocol {
    func didReceive(exportData: ExportSeedData) {
        self.exportData = exportData

        let viewModel = ExportGenericViewModel(
            sourceDetails: exportData.seed.toHex(includePrefix: true)
        )

        view?.set(viewModel: viewModel)
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}
