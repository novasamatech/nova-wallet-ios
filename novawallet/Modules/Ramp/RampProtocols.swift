import UIKit

protocol RampViewProtocol: ControllerBackedProtocol {
    func didReceive(model: RampModel)
}

protocol RampPresenterProtocol: AnyObject {
    func setup()
    func processMessage(body: Any, of name: String)
}

protocol RampInteractorInputProtocol: AnyObject {
    func setup()
    func processMessage(body: Any, of name: String)
}

protocol RampInteractorOutputProtocol: AnyObject {
    func didReceive(model: RampModel)
    func didCompleteOperation(action: RampAction)
    func didRequestTransfer(for model: PayCardTopupModel)
}

protocol RampWireframeProtocol: AnyObject {
    func showSend(
        from view: ControllerBackedProtocol?,
        with transferModel: PayCardTopupModel
    )

    func complete(
        from view: RampViewProtocol?,
        with action: RampActionType,
        for chainAsset: ChainAsset
    )
}

protocol RampFlowStartingDelegate: AnyObject {
    func didPickRampParams(
        actions: [RampAction],
        rampType: RampActionType,
        chainAsset: ChainAsset
    )
}
