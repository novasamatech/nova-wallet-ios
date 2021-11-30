final class AccountCreatePresenter: BaseAccountCreatePresenter {
    let walletName: String

    init(walletName: String) {
        self.walletName = walletName
    }

    override func processProceed() {
        guard let metadata = metadata,
              let substrateCryptoType = selectedSubstrateCryptoType
        else { return }

        let request = MetaAccountCreationRequest(
            username: walletName,
            derivationPath: substrateDerivationPath,
            ethereumDerivationPath: ethereumDerivationPath,
            cryptoType: substrateCryptoType
        )

        wireframe.confirm(from: view, request: request, metadata: metadata)
    }
}
