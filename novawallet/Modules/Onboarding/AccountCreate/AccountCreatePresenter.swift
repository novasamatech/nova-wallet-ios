import SoraFoundation
final class AccountCreatePresenter: BaseAccountCreatePresenter {
    let walletName: String

    init(
        walletName: String,
        localizationManager: LocalizationManagerProtocol,
        checkboxListViewModelFactory: CheckboxListViewModelFactory,
        mnemonicViewModelFactory: MnemonicViewModelFactory
    ) {
        self.walletName = walletName

        super.init(
            localizationManager: localizationManager,
            checkboxListViewModelFactory: checkboxListViewModelFactory,
            mnemonicViewModelFactory: mnemonicViewModelFactory
        )
    }

    override func processProceed() {
        let selectedSubstrateCryptoType = selectedSubstrateCryptoType ?? availableCrypto?.defaultCryptoType

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
        guard let availableCrypto = availableCrypto else {
            return nil
        }

        let substrateSettings = AdvancedNetworkTypeSettings(
            availableCryptoTypes: availableCrypto.availableCryptoTypes,
            selectedCryptoType: selectedSubstrateCryptoType ?? availableCrypto.defaultCryptoType,
            derivationPath: substrateDerivationPath
        )

        return .combined(
            substrateSettings: substrateSettings,
            ethereumDerivationPath: ethereumDerivationPath
        )
    }
}
