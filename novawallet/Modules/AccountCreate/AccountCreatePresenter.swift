import SoraFoundation
final class AccountCreatePresenter: BaseAccountCreatePresenter {
    let walletName: String

    init(
        walletName: String,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.walletName = walletName
        super.init(localizationManager: localizationManager)
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

    override func getAdvancedSettings() -> AdvancedWalletSettings? {
        guard let metadata = metadata else {
            return nil
        }

        let substrateSettings = AdvancedNetworkTypeSettings(
            availableCryptoTypes: metadata.availableCryptoTypes,
            selectedCryptoType: selectedSubstrateCryptoType ?? metadata.defaultCryptoType,
            derivationPath: substrateDerivationPath
        )

        return .combined(
            substrateSettings: substrateSettings,
            ethereumDerivationPath: ethereumDerivationPath
        )
    }
}
