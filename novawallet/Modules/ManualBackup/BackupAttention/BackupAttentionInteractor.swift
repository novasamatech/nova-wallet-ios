import Foundation
import Keystore_iOS

class BackupAttentionInteractor: BackupAttentionInteractorInputProtocol {
    private let keystore: KeystoreProtocol
    private let metaAccount: MetaAccountModel
    private let chain: ChainModel?

    init(
        keystore: KeystoreProtocol,
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) {
        self.keystore = keystore
        self.metaAccount = metaAccount
        self.chain = chain
    }

    func checkIfMnemonicAvailable() -> Bool {
        var accountId: AccountId? {
            if let chain {
                metaAccount.fetchChainAccountId(for: chain.accountRequest())
            } else {
                .none
            }
        }

        let entropyTag = KeystoreTagV2.entropyTagForMetaId(
            metaAccount.metaId,
            accountId: accountId
        )

        return (try? keystore.checkKey(for: entropyTag)) ?? false
    }
}
