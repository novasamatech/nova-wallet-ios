import Foundation
import SoraFoundation

final class AccountImportPresenter: BaseAccountImportPresenter {
    override func processProceed() {
        guard
            let selectedCryptoType = selectedCryptoType,
            let sourceViewModel = sourceViewModel,
            let usernameViewModel = usernameViewModel
        else {
            return
        }

        guard selectedCryptoType != .ethereumEcdsa else {
            // we don't support ethereum crypto for wallets

            wireframe.present(
                message: R.string.localizable.importJsonUnsupportedSubstrateCryptoMessage(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                title: R.string.localizable.commonErrorGeneralTitle(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
                from: view
            )

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
        let ethereumDerivationPath = self.ethereumDerivationPath ?? ""

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
            selectedCryptoType: selectedCryptoType ?? metadata.defaultCryptoType,
            derivationPath: substrateDerivationPath
        )

        switch selectedSourceType {
        case .mnemonic:
            return .combined(
                substrateSettings: substrateSettings,
                ethereumDerivationPath: ethereumDerivationPath
            )
        case .seed, .keystore:
            return .substrate(settings: substrateSettings)
        }
    }
}
