import Foundation
import Web3Core

struct EvmBalanceUpdateBlock {
    let updateDetectedAt: Web3Core.BlockNumber?
    let fetchRequestedAt: Web3Core.BlockNumber
}
