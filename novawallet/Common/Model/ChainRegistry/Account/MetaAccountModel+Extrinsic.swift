import Foundation

extension MetaAccountModel {
    func delaysCallExecution(in chain: ChainModel) -> Bool {
        guard let multisig = getMultisig(for: chain) else { return false }

        return multisig.threshold > 1
    }
}
