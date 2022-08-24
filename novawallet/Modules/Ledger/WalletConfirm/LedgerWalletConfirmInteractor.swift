import UIKit

final class LedgerWalletConfirmInteractor {
    weak var presenter: LedgerWalletConfirmInteractorOutputProtocol?

    let accountsStore: LedgerAccountsStore
    let operationQueue: OperationQueue
    let settings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol

    init(
        accountsStore: LedgerAccountsStore,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.accountsStore = accountsStore
        self.settings = settings
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }
}

extension LedgerWalletConfirmInteractor: LedgerWalletConfirmInteractorInputProtocol {
    func save(with _: String) {}
}
