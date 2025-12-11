import Operation_iOS
import Foundation_iOS

protocol PVAddressesInteractorInputProtocol: AnyObject {
    func setup()
}

protocol PVAddressesInteractorOutputProtocol: AnyObject {
    func didReceive(accountId: AccountId)
    func didReceive(account: PolkadotVaultAccount)
    func didReceive(chains: [DataProviderChange<ChainModel>])
    func didReceive(error: Error)
}

protocol PVAddressesWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable {
    func showConfirmation(
        on view: HardwareWalletAddressesViewProtocol?,
        account: PolkadotVaultAccount,
        type: ParitySignerType
    )
}
