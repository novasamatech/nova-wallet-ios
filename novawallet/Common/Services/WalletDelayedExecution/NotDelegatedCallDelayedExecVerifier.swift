import Foundation

final class NotDelegatedCallDelayedExecVerifier {
    let selectedWallet: MetaAccountModel

    init(selectedWallet: MetaAccountModel) {
        self.selectedWallet = selectedWallet
    }
}

extension NotDelegatedCallDelayedExecVerifier: WalletDelayedExecVerifing {
    func executesCallWithDelay(
        _ wallet: MetaAccountModel,
        chain: ChainModel
    ) -> Bool {
        guard wallet.isDelegated() else {
            return false
        }

        return wallet.delaysCallExecution(in: chain)
    }
}
