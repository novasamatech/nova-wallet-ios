import Foundation

final class CloudBackupReviewChangesWireframe: CloudBackupReviewChangesWireframeProtocol {
    func close(view: CloudBackupReviewChangesViewProtocol?, closure: (() -> Void)?) {
        view?.controller.dismiss(animated: true, completion: closure)
    }
}
