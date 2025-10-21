import Foundation

protocol StashLedgerStateProtocol {
    var stashItem: StashItem { get }
    var ledgerInfo: Staking.Ledger { get }
}
