import Foundation
import SoraFoundation

final class AccountImportPresenter: BaseAccountImportPresenter {
    override func processProceed() {
        guard
            let selectedCryptoType = selectedSubstrateCryptoType,
            let sourceViewModel = sourceViewModel,
            let usernameViewModel = usernameViewModel
        else {
            return
        }

        if let error = validateSourceViewModel() {
            _ = wireframe.present(
                error: error,
                from: view,
                locale: localizationManager?.selectedLocale
            )
            return
        }

        let username = usernameViewModel.inputHandler.value
        let substrateDerivationPath = self.substrateDerivationPath ?? ""

        let ethereumDerivationPathValue = self.ethereumDerivationPath ?? ""
        let ethereumDerivationPath = ethereumDerivationPathValue.isEmpty ?
            DerivationPathConstants.defaultEthereum : ethereumDerivationPathValue

        switch selectedSourceType {
        case .mnemonic:
            let mnemonic = sourceViewModel.inputHandler.normalizedValue
            let request = MetaAccountImportMnemonicRequest(
                mnemonic: mnemonic,
                username: username,
                derivationPath: substrateDerivationPath,
                ethereumDerivationPath: ethereumDerivationPath,
                cryptoType: selectedCryptoType
            )

            interactor.importAccountWithMnemonic(request: request)

        case .seed:
            let seed = sourceViewModel.inputHandler.value
            let request = MetaAccountImportSeedRequest(
                seed: seed,
                username: username,
                derivationPath: substrateDerivationPath,
                cryptoType: selectedCryptoType
            )

            interactor.importAccountWithSeed(request: request)

        case .keystore:
            let keystore = sourceViewModel.inputHandler.value
            let password = passwordViewModel?.inputHandler.value ?? ""
            let request = MetaAccountImportKeystoreRequest(
                keystore: keystore,
                password: password,
                username: username,
                cryptoType: selectedCryptoType
            )

            interactor.importAccountWithKeystore(request: request)
        }
    }

    override func showUploadWarningIfNeeded(_: MetaAccountImportPreferredInfo) {}

    override func shouldUseEthereumSeed() -> Bool { false }

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
