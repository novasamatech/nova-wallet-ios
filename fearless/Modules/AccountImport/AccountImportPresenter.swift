import Foundation
import SoraFoundation

final class AccountImportPresenter: BaseAccountImportPresenter {
    override func processProceed() {
        guard
            let selectedSourceType = selectedSourceType,
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

        var derivationPathCheckError = false
        if let viewModel = substrateDerivationPathViewModel, !viewModel.inputHandler.completed {
            derivationPathCheckError = true
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(sourceType: selectedSourceType, cryptoType: selectedCryptoType)
        }

        if let viewModel = ethereumDerivationPathViewModel, !viewModel.inputHandler.completed {
            view?.didValidateEthereumDerivationPath(.invalid)
            if !derivationPathCheckError {
                presentDerivationPathError(sourceType: selectedSourceType, cryptoType: .ethereumEcdsa)
                derivationPathCheckError = true
            }
        }

        guard !derivationPathCheckError else { return }

        let username = usernameViewModel.inputHandler.value
        let substrateDerivationPath = substrateDerivationPathViewModel?.inputHandler.value ?? ""

        let ethereumDerivationPathValue = ethereumDerivationPathViewModel?.inputHandler.value ?? ""
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

    override func setViewTitle() {
        let title = R.string.localizable
            .importWalletTitle(preferredLanguages: selectedLocale.rLanguages)
        view?.setTitle(title)
    }

    override func showUploadWarningIfNeeded(_: MetaAccountImportPreferredInfo) {}
}
