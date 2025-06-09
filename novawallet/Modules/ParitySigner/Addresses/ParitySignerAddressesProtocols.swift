import Operation_iOS
import Foundation_iOS

protocol ParitySignerAddressesInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ParitySignerAddressesInteractorOutputProtocol: AnyObject {
    func didReceive(chains: [DataProviderChange<ChainModel>])
}

protocol ParitySignerAddressesWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable {
    func showConfirmation(
        on view: HardwareWalletAddressesViewProtocol?,
        walletFormat: ParitySignerWalletFormat,
        type: ParitySignerType
    )
}
