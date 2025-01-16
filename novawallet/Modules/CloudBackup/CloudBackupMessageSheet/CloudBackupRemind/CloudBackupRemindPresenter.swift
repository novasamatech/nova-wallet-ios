import Foundation_iOS
import Keystore_iOS

final class CloudBackupRemindPresenter: MessageSheetPresenter, CloudBackupRemindPresenterProtocol {
    let interactor: CloudBackupRemindInteractorInputProtocol

    init(interactor: CloudBackupRemindInteractorInputProtocol, wireframe: MessageSheetWireframeProtocol) {
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
