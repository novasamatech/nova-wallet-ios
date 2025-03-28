import UIKit

protocol AssetReceiveViewProtocol: ControllerBackedProtocol {
    func didReceive(networkViewModel: NetworkViewModel)
    func didReceive(
        addressViewModel: AccountAddressViewModel,
        networkName: String,
        token: String
    )
    func didReceive(qrResult: QRCodeWithLogoFactory.QRCreationResult)
}

protocol AssetReceivePresenterProtocol: AnyObject {
    func setup()
    func set(qrCodeSize: CGSize)
    func share()
    func copyAddress()
    func viewAddressFormats()
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

protocol AssetReceiveWireframeProtocol: AnyObject,
    SharingPresentable,
    ErrorPresentable,
    AlertPresentable,
    CommonRetryable,
    ModalAlertPresenting,
    CopyAddressPresentable,
    UnifiedAddressPopupPresentable {}
