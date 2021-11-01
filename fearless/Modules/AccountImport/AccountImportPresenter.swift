import Foundation
import SoraFoundation

final class AccountImportPresenter: BaseAccountImportPresenter {
    override func processProceed() {
        guard
            let selectedSourceType = selectedSourceType,
            let selectedCryptoType = selectedCryptoType,
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

        if let viewModel = substrateDerivationPathViewModel, !viewModel.inputHandler.completed {
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(sourceType: selectedSourceType, cryptoType: selectedCryptoType)

            return
        }

        if let viewModel = ethereumDerivationPathViewModel, !viewModel.inputHandler.completed {
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(sourceType: selectedSourceType, cryptoType: selectedCryptoType)

            return
        }

        let username = usernameViewModel.inputHandler.value
        let substrateDerivationPath = substrateDerivationPathViewModel?.inputHandler.value ?? ""

        let ethereumDerivationPath = substrateDerivationPathViewModel?.inputHandler.value ??
            DerivationPathConstants.defaultEthereum

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

    override func getVisibilitySettings() -> AccountImportVisibility {
        guard let sourceType = selectedSourceType else {
            return .walletMnemonic
        }

        switch sourceType {
        case .mnemonic:
            return .walletMnemonic
        case .seed:
            return .walletSeed
        case .keystore:
            return .walletJSON
        }
    }
}
