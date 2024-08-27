import Foundation

protocol PayCardViewProtocol: ControllerBackedProtocol {
    func didReceiveRefundAddress(_ refundAddress: String)
}

protocol PayCardPresenterProtocol: AnyObject {
    func setup()
    func onTransferDataReceive(data: Data)
}

protocol PayCardInteractorInputProtocol: AnyObject {
    func process(_ data: Data)
}

protocol PayCardInteractorOutputProtocol: AnyObject {
    func didReceive(_ transferModel: MercuryoTransferModel)
}

protocol PayCardWireframeProtocol: AnyObject {
    func showSend(
        from view: ControllerBackedProtocol?,
        with transferModel: MercuryoTransferModel
    )
}
