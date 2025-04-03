import UIKit
import Foundation_iOS

protocol ParitySignerTxQrViewProtocol: ControllerBackedProtocol {
    func didReceiveWallet(viewModel: WalletAccountViewModel)
    func didReceiveCode(viewModel: QRImageViewModel)
    func didReceiveExpiration(viewModel: ExpirationTimeViewModel)
}

protocol ParitySignerTxQrPresenterProtocol: AnyObject {
    func setup(qrSize: CGSize)
    func activateAddressDetails()
    func activateTroubleshouting()
    func proceed()
    func close()
}

protocol ParitySignerTxQrInteractorInputProtocol: AnyObject {
    func setup(qrSize: CGSize)
}

protocol ParitySignerTxQrInteractorOutputProtocol: AnyObject {
    func didReceive(chainWallet: ChainWalletDisplayAddress)
    func didReceive(transactionCode: TransactionDisplayCode)
    func didReceive(error: Error)
}

protocol ParitySignerTxQrWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable, WebPresentable, TransactionExpiredPresentable {
    func close(view: ParitySignerTxQrViewProtocol?)

    func proceed(
        from view: ParitySignerTxQrViewProtocol?,
        accountId: AccountId,
        type: ParitySignerType,
        timer: CountdownTimerMediating,
        completion: @escaping TransactionSigningClosure
    )
}
