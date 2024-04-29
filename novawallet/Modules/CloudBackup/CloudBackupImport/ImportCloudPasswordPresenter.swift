import Foundation

final class ImportCloudPasswordPresenter {
    weak var view: ImportCloudPasswordViewProtocol?
    let wireframe: ImportCloudPasswordWireframeProtocol
    let interactor: ImportCloudPasswordInteractorInputProtocol

    init(
        interactor: ImportCloudPasswordInteractorInputProtocol,
        wireframe: ImportCloudPasswordWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ImportCloudPasswordPresenter: ImportCloudPasswordPresenterProtocol {
    func setup() {}
    
    func activateContinue() {}
}

extension ImportCloudPasswordPresenter: ImportCloudPasswordInteractorOutputProtocol {}
