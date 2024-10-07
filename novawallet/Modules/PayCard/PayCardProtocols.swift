import Foundation

protocol PayCardViewProtocol: ControllerBackedProtocol {
    func didReceive(model: PayCardModel)
}

protocol PayCardPresenterProtocol: AnyObject {
    func setup()
    func processMessage(body: Any, of name: String)
}

protocol PayCardInteractorInputProtocol: AnyObject {
    func setup()
    func processMessage(body: Any, of name: String)
}

protocol PayCardInteractorOutputProtocol: AnyObject {
    func didReceive(model: PayCardModel)
    func didRequestTopup(for model: PayCardTopupModel)
}

protocol PayCardWireframeProtocol: AnyObject {
    func showSend(
        from view: ControllerBackedProtocol?,
        with transferModel: PayCardTopupModel,
        transferCompletion: @escaping TransferCompletionClosure
    )
}
