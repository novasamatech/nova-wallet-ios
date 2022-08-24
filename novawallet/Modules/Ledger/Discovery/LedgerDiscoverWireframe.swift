import Foundation

final class LedgerDiscoverWireframe: LedgerDiscoverWireframeProtocol {
    let accountsStore: LedgerAccountsStore

    init(accountsStore: LedgerAccountsStore) {
        self.accountsStore = accountsStore
    }

    func showAccountSelection(from _: LedgerDiscoverViewProtocol?, chain _: ChainModel, deviceId: UUID) {
        // TODO: Implement navigation to account selection
        assertionFailure("Implement account selection for \(deviceId)")
    }
}
