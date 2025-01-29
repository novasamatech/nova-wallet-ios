import Foundation

protocol PayCardViewProtocol: ControllerBackedProtocol {
    func didReceive(model: PayCardModel)
}

protocol PayCardPresenterProtocol: AnyObject {
    func setup()
    func processMessage(body: Any, of name: String)
    func processPhotoLibraryAuth(errorCode: PayCardWebViewErrorCode)
}

protocol PayCardInteractorInputProtocol: AnyObject {
    func setup()
    func processIssueInit()
    func processMessage(body: Any, of name: String)
    func checkPendingTimeout()
}

protocol PayCardInteractorOutputProtocol: AnyObject {
    func didReceive(model: PayCardModel)
    func didRequestTopup(for model: PayCardTopupModel)
    func didReceiveCardStatus(_ cardStatus: PayCardStatus)
}

protocol PayCardWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showSend(
        from view: ControllerBackedProtocol?,
        with transferModel: PayCardTopupModel,
        transferCompletion: @escaping TransferCompletionClosure
    )

    func showCardOpenPending(
        from view: ControllerBackedProtocol?,
        timerMediator: CountdownTimerMediator,
        totalTime: TimeInterval,
        locale: Locale?
    )

    func closeCardOpenSheet(
        from view: ControllerBackedProtocol?,
        completion: (() -> Void)?
    )
}
