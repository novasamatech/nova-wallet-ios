import UIKit

protocol AssetReceiveViewProtocol: ControllerBackedProtocol {
    func didReceive(chainAccountViewModel: ChainAccountViewModel, token: String)
    func didReceive(qrImage: UIImage)
}

protocol AssetReceivePresenterProtocol: AnyObject {
    func setup()
    func set(qrCodeSize: CGSize)
    func share()
    func presentAccountOptions()
}

protocol AssetReceiveInteractorInputProtocol: AnyObject {
    func setup()
    func generateQRCode(size: CGSize)
}

protocol AssetReceiveInteractorOutputProtocol: AnyObject {
    func didReceive(account: MetaChainAccountResponse, chain: ChainModel, token: String)
    func didReceive(qrCodeInfo: QRCodeInfo)
    func didReceive(error: AssetReceiveInteractorError)
}

protocol AssetReceiveWireframeProtocol: AnyObject, SharingPresentable, AddressOptionsPresentable, ErrorPresentable, AlertPresentable, CommonRetryable {}
