import UIKit
import Foundation_iOS

protocol ParitySignerTxQrViewProtocol: ControllerBackedProtocol {
    func didReceiveWallet(viewModel: WalletAccountViewModel)
    func didReceiveCode(viewModel: QRImageViewModel?)
    func didReceiveQrFormat(viewModel: ParitySignerTxFormatViewModel)
    func didReceiveExpiration(viewModel: ExpirationTimeViewModel?)
}

protocol ParitySignerTxQrPresenterProtocol: AnyObject {
    func setup(qrSize: CGSize)
    func activateAddressDetails()
    func activateTroubleshouting()
    func toggleExtrinsicFormat()
    func proceed()
    func close()
}

protocol ParitySignerTxQrInteractorInputProtocol: AnyObject {
    func setup()
    func generateQr(with format: ParitySignerQRFormat, qrSize: CGSize)
}

protocol ParitySignerTxQrInteractorOutputProtocol: AnyObject {
    func didCompleteSetup(model: ParitySignerTxQrSetupModel)
    func didReceive(transactionCode: TransactionDisplayCode)
    func didReceive(error: Error)
}

protocol ParitySignerTxQrWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable, WebPresentable, TransactionExpiredPresentable {
    func close(view: ParitySignerTxQrViewProtocol?)

    func proceed(
        from view: ParitySignerTxQrViewProtocol?,
        verificationModel: ParitySignerSignatureVerificationModel,
        timer: CountdownTimerMediating?,
        completion: @escaping TransactionSigningClosure
    )
}
