import Foundation_iOS

protocol MultisigCallDataImportViewProtocol: ControllerBackedProtocol {
    func didReceive(callDataViewModel: InputViewModelProtocol)
}

protocol MultisigCallDataImportPresenterProtocol: AnyObject {
    func setup()
    func save()
}

protocol MultisigCallDataImportInteractorInputProtocol: AnyObject {
    func importCallData(_ callDataString: String)
}

protocol MultisigCallDataImportInteractorOutputProtocol: AnyObject {
    func didReceive(importResult: Result<Void, Error>)
}

protocol MultisigCallDataImportWireframeProtocol: ErrorPresentable, AlertPresentable {
    func proceedAfterImport(from view: MultisigCallDataImportViewProtocol?)
}
