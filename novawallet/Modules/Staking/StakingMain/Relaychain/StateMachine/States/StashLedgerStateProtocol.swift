import Foundation

protocol StashLedgerStateProtocol {
    var stashItem: StashItem { get }
    var ledgerInfo: StakingLedger { get }
}
