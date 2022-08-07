import UIKit

protocol ParitySignerTxQrViewProtocol: ControllerBackedProtocol {
    func didReceiveWallet(viewModel: WalletAccountViewModel)
    func didReceiveCode(viewModel: UIImage)
}

protocol ParitySignerTxQrPresenterProtocol: AnyObject {
    func setup(qrSize: CGSize)
    func activateAddressDetails()
    func activateTroubleshouting()
    func proceed()
}

protocol ParitySignerTxQrInteractorInputProtocol: AnyObject {
    func setup(qrSize: CGSize)
}

protocol ParitySignerTxQrInteractorOutputProtocol: AnyObject {
    func didReceive(chainWallet: ChainWalletDisplayAddress)
    func didReceive(transactionCode: TransactionDisplayCode)
    func didReceive(error: Error)
}

protocol ParitySignerTxQrWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable {}
