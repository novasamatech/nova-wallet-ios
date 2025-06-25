import Operation_iOS
import Foundation_iOS

protocol ParitySignerAddressesInteractorInputProtocol: AnyObject {
    func setup()
    func confirm()
}

protocol ParitySignerAddressesInteractorOutputProtocol: AnyObject {
    func didReceive(chains: [DataProviderChange<ChainModel>])
    func didReceiveConfirm(result: Result<Void, Error>)
}

protocol ParitySignerAddressesWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable {
    func showConfirmation(
        on view: HardwareWalletAddressesViewProtocol?,
        walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType
    )
}
