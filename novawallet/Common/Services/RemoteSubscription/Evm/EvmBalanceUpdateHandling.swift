import Foundation
import Operation_iOS
import Core

protocol EvmBalanceUpdateHandling {
    func onBalanceUpdateWrapper(
        balances: [ChainAssetId: Balance],
        holder: AccountAddress,
        block: Core.BlockNumber?
    ) -> CompoundOperationWrapper<Bool>
}
