import Foundation

final class MultisigCallDataImportWireframe: MultisigCallDataImportWireframeProtocol {
    func proceedAfterImport(from view: MultisigCallDataImportViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
