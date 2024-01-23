import SoraFoundation
import SoraKeystore

final class ProxyMessageSheetPresenter: MessageSheetPresenter, ProxyMessageSheetPresenterProtocol {
    let interactor: ProxyMessageSheetInteractorInputProtocol

    init(interactor: ProxyMessageSheetInteractorInputProtocol, wireframe: MessageSheetWireframeProtocol) {
        self.interactor = interactor
        super.init(wireframe: wireframe)
    }

    func proceed(skipInfoNextTime: Bool, action: MessageSheetAction?) {
        if skipInfoNextTime {
            interactor.saveNoConfirmation { [weak self] in
                self?.wireframe.complete(on: self?.view, with: action)
            }
        } else {
            wireframe.complete(on: view, with: action)
        }
    }
}
