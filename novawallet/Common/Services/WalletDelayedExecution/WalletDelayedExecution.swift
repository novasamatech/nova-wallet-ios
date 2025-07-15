import Foundation

protocol WalletDelayedExecuting {
    func executesCallWithDelay(_ wallet: MetaAccountModel, chain: ChainModel) -> Bool
}

final class WalletDelayedExecution {
    let allWallet: [MetaAccountModel.Id: MetaAccountModel]

    init(allWallet: [MetaAccountModel.Id: MetaAccountModel]) {
        self.allWallet = allWallet
    }
}

extension WalletDelayedExecution: WalletDelayedExecuting {
    func executesCallWithDelay(_: MetaAccountModel, chain _: ChainModel) -> Bool {
        false
    }
}
