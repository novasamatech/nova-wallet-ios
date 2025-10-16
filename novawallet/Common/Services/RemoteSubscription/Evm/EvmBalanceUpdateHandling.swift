import Foundation
import Operation_iOS
import Web3Core

protocol EvmBalanceUpdateHandling {
    func onBalanceUpdateWrapper(
        balances: [ChainAssetId: Balance],
        holder: AccountAddress,
        block: Web3Core.BlockNumber?
    ) -> CompoundOperationWrapper<Bool>
}
