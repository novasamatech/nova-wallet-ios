import UIKit

protocol ReceiveViewProtocol: ControllerBackedProtocol {
    func didReceive(chainAccountViewModel: ChainAccountViewModel, token: String)
    func didReceive(qrImage: UIImage)
}

protocol ReceivePresenterProtocol: AnyObject {
    func setup()
    func set(qrCodeSize: CGSize)
    func share()
    func presentAccountOptions()
}

protocol ReceiveInteractorInputProtocol: AnyObject {
    func setup()
    func set(qrCodeSize: CGSize)
}

protocol ReceiveInteractorOutputProtocol: AnyObject {
    func didReceive(account: MetaChainAccountResponse, chain: ChainModel, token: String)
    func didReceive(qrCodeInfo: QRCodeInfo)
    func didReceive(error: ReceiveInteractorError)
}

protocol ReceiveWireframeProtocol: AnyObject, SharingPresentable, AddressOptionsPresentable {}
