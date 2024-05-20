import Foundation

final class AdvancedExportPresenter {
    weak var view: AdvancedExportViewProtocol?
    let wireframe: AdvancedExportWireframeProtocol
    let interactor: AdvancedExportInteractorInputProtocol

    init(
        interactor: AdvancedExportInteractorInputProtocol,
        wireframe: AdvancedExportWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension AdvancedExportPresenter: AdvancedExportPresenterProtocol {
    func setup() {}
}

extension AdvancedExportPresenter: AdvancedExportInteractorOutputProtocol {}