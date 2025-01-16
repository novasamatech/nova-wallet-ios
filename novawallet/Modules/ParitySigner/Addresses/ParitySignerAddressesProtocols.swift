import Operation_iOS
import Foundation_iOS

protocol ParitySignerAddressesInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ParitySignerAddressesInteractorOutputProtocol: AnyObject {
    func didReceive(accountId: AccountId)
    func didReceive(chains: [DataProviderChange<ChainModel>])
    func didReceive(error: Error)
}

protocol ParitySignerAddressesWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable {
    func showConfirmation(
        on view: HardwareWalletAddressesViewProtocol?,
        accountId: AccountId,
        type: ParitySignerType
    )
}
