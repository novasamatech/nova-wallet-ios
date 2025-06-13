import Foundation

extension MetaAccountModel {
    var vaultRootKeyId: Data? {
        guard type == .polkadotVaultRoot else {
            return nil
        }

        return substrateAccountId
    }
}
