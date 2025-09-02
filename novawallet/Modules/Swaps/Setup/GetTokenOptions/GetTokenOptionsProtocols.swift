import Foundation
import Foundation_iOS

protocol GetTokenOptionsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [LocalizableResource<TokenOperationTableViewCell.Model>])
}

protocol GetTokenOptionsPresenterProtocol: AnyObject {
    func setup()
    func selectOption(at index: Int)
}

protocol GetTokenOptionsWireframeProtocol: AnyObject {
    func complete(on view: GetTokenOptionsViewProtocol?, result: GetTokenOptionsResult)
}

protocol GetTokenOptionsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol GetTokenOptionsInteractorOutputProtocol: AnyObject {
    func didReceive(model: GetTokenOptionsModel)
}
