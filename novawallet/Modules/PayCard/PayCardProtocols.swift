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
    func processSuccessTopup()
    func processMessage(body: Any, of name: String)
}

protocol PayCardInteractorOutputProtocol: AnyObject {
    func didReceive(model: PayCardModel)
    func didRequestTopup(for model: PayCardTopupModel)
    func didReceiveCardOpenTimestamp(_ timestamp: TimeInterval)
    func didReceiveCardStatus(_ cardStatus: PayCardStatus)
}

protocol PayCardWireframeProtocol: AlertPresentable {
    func showSend(
        from view: ControllerBackedProtocol?,
        with transferModel: PayCardTopupModel,
        transferCompletion: @escaping TransferCompletionClosure
    )

    func showCardOpenPending(
        from view: ControllerBackedProtocol?,
        timerMediator: CountdownTimerMediator,
        locale: Locale?
    )

    func closeCardOpenSheet(
        from view: ControllerBackedProtocol?,
        completion: (() -> Void)?
    )

    func close(from view: ControllerBackedProtocol?)
}
