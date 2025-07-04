import Foundation

final class MultisigCallDataImportWireframe: MultisigCallDataImportWireframeProtocol {
    func proceedAfterImport(from view: MultisigCallDataImportViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
