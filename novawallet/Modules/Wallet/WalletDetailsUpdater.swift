import Foundation
import CommonWallet

protocol WalletDetailsUpdating: AnyObject {
    var context: CommonWalletContextProtocol? { get set }
}

final class WalletDetailsUpdater: WalletDetailsUpdating, EventVisitorProtocol {
    static let shared = WalletDetailsUpdater(eventCenter: EventCenter.shared)

    weak var context: CommonWalletContextProtocol?
    let eventCenter: EventCenterProtocol

    init(eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func processBalanceChanged(event _: WalletBalanceChanged) {
        try? context?.prepareAccountUpdateCommand().execute()
    }

    func processNewTransaction(event _: WalletNewTransactionInserted) {
        try? context?.prepareAccountUpdateCommand().execute()
    }
}
