import Foundation
import UIKit
import Operation_iOS

enum DelegatedAccountsUpdateMode {
    case proxied
    case multisig
}

protocol DelegatedAccountsUpdateViewProtocol: ControllerBackedProtocol {
    func didReceive(
        delegatedModels: [WalletView.ViewModel],
        revokedModels: [WalletView.ViewModel],
        shouldShowSegmentedControl: Bool
    )
    func preferredContentHeight(
        delegatedModelsCount: Int,
        revokedModelsCount: Int,
        shouldShowSegmentedControl: Bool
    ) -> CGFloat

    func switchMode(_ mode: DelegatedAccountsUpdateMode)
}

protocol DelegatedAccountsUpdatePresenterProtocol: AnyObject {
    func setup()
    func done()
    func showInfo()
    func didSelectMode(_ mode: DelegatedAccountsUpdateMode)
}

protocol DelegatedAccountsUpdateInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DelegatedAccountsUpdateInteractorOutputProtocol: AnyObject {
    func didReceiveWalletsChanges(_ changes: [DataProviderChange<ManagedMetaAccountModel>])
    func didReceiveChainChanges(_ changes: [DataProviderChange<ChainModel>])
    func didReceiveError(_ error: DelegatedAccountsUpdateError)
}

protocol DelegatedAccountsUpdateWireframeProtocol: AnyObject, WebPresentable {
    func close(from view: ControllerBackedProtocol?)
    func close(from view: ControllerBackedProtocol?, andPresent url: URL)
}

enum DelegatedAccountsUpdateError: Error {
    case subscription(Error)
}
