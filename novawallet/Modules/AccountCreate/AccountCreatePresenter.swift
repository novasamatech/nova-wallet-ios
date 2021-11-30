import UIKit
import IrohaCrypto
import SoraFoundation

// TODO: Reefactor (rename + restruct)
final class AccountCreatePresenter: BaseAccountCreatePresenter {
    let walletName: String

    init(walletName: String) {
        self.walletName = walletName
    }

    func processProceed() {
        guard let metadata = metadata else { return }

        // TODO: Get real values
        let cryptoType: MultiassetCryptoType = .sr25519

        let substrateDerivationPath = ""
        let ethereumDerivationPath = DerivationPathConstants.defaultEthereum

        let request = MetaAccountCreationRequest(
            username: walletName,
            derivationPath: substrateDerivationPath,
            ethereumDerivationPath: ethereumDerivationPath,
            cryptoType: cryptoType
        )

        wireframe.confirm(from: view, request: request, metadata: metadata)
    }
}
