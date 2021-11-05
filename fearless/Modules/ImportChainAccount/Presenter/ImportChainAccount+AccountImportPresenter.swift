import Foundation
import SoraFoundation

extension ImportChainAccount {
    final class AccountImportPresenter: BaseAccountImportPresenter {
        let metaAccountModel: MetaAccountModel
        let chainModelId: ChainModel.Id
        let isEthereumBased: Bool

        init(
            metaAccountModel: MetaAccountModel,
            chainModelId: ChainModel.Id,
            isEthereumBased: Bool
        ) {
            self.metaAccountModel = metaAccountModel
            self.chainModelId = chainModelId
            self.isEthereumBased = isEthereumBased
        }

        private func prooceedWithSubstrate() {
            guard
                let selectedSourceType = selectedSourceType,
                let selectedCryptoType = selectedCryptoType,
                let sourceViewModel = sourceViewModel
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
            let substrateDerivationPath = substrateDerivationPathViewModel?.inputHandler.value ?? ""

            switch selectedSourceType {
            case .mnemonic:
                let mnemonic = sourceViewModel.inputHandler.normalizedValue
                let request = ChainAccountImportMnemonicRequest(
                    mnemonic: mnemonic,
                    derivationPath: substrateDerivationPath,
                    cryptoType: selectedCryptoType
                )

                interactor.importAccountWithMnemonic(
                    chainId: chainModelId,
                    request: request,
                    into: metaAccountModel
                )

            case .seed:
                let seed = sourceViewModel.inputHandler.value
                let request = ChainAccountImportSeedRequest(
                    seed: seed,
                    derivationPath: substrateDerivationPath,
                    cryptoType: selectedCryptoType
                )

                interactor.importAccountWithSeed(
                    chainId: chainModelId,
                    request: request,
                    into: metaAccountModel
                )

            case .keystore:
                let keystore = sourceViewModel.inputHandler.value
                let password = passwordViewModel?.inputHandler.value ?? ""
                let request = ChainAccountImportKeystoreRequest(
                    keystore: keystore,
                    password: password,
                    cryptoType: selectedCryptoType
                )

                interactor.importAccountWithKeystore(
                    chainId: chainModelId,
                    request: request,
                    into: metaAccountModel
                )
            }
        }

        private func proceedWithEthereum() {
            guard
                let selectedSourceType = selectedSourceType,
                let sourceViewModel = sourceViewModel
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

            let selectedCryptoType: MultiassetCryptoType = .ethereumEcdsa

            if let viewModel = ethereumDerivationPathViewModel, !viewModel.inputHandler.completed {
                view?.didValidateSubstrateDerivationPath(.invalid)
                presentDerivationPathError(sourceType: selectedSourceType, cryptoType: selectedCryptoType)

                return
            }

            let ethereumDerivationPath = substrateDerivationPathViewModel?.inputHandler.value ??
                DerivationPathConstants.defaultEthereum

            switch selectedSourceType {
            case .mnemonic:
                let mnemonic = sourceViewModel.inputHandler.normalizedValue
                let request = ChainAccountImportMnemonicRequest(
                    mnemonic: mnemonic,
                    derivationPath: ethereumDerivationPath,
                    cryptoType: selectedCryptoType
                )

                interactor.importAccountWithMnemonic(
                    chainId: chainModelId,
                    request: request,
                    into: metaAccountModel
                )

            case .seed:
                let seed = sourceViewModel.inputHandler.value
                let request = ChainAccountImportSeedRequest(
                    seed: seed,
                    derivationPath: ethereumDerivationPath,
                    cryptoType: selectedCryptoType
                )

                interactor.importAccountWithSeed(
                    chainId: chainModelId,
                    request: request,
                    into: metaAccountModel
                )

            case .keystore:
                let keystore = sourceViewModel.inputHandler.value
                let password = passwordViewModel?.inputHandler.value ?? ""
                let request = ChainAccountImportKeystoreRequest(
                    keystore: keystore,
                    password: password,
                    cryptoType: selectedCryptoType
                )

                interactor.importAccountWithKeystore(
                    chainId: chainModelId,
                    request: request,
                    into: metaAccountModel
                )
            }
        }

        override func processProceed() {
            if isEthereumBased {
                proceedWithEthereum()
            } else {
                prooceedWithSubstrate()
            }
        }

        override func getVisibilitySettings() -> AccountImportVisibility {
            guard let sourceType = selectedSourceType else {
                return isEthereumBased ? .ethereumChainMnemonic : .substrateChainMnemonic
            }

            switch sourceType {
            case .mnemonic:
                return isEthereumBased ? .ethereumChainMnemonic : .substrateChainMnemonic
            case .seed:
                return isEthereumBased ? .ethereumChainSeed : .substrateChainSeed
            case .keystore:
                return isEthereumBased ? .ethereumChainJSON : .substrateChainJSON
            }
        }

        override func applyUsernameViewModel(_: String = "") {
            view?.setName(viewModel: nil)
        }

        override func setViewTitle() {
            let title = R.string.localizable
                .importChainAccountTitle(preferredLanguages: selectedLocale.rLanguages)
            view?.setTitle(title)
        }

        override func showUploadWarningIfNeeded(_ preferredInfo: MetaAccountImportPreferredInfo) {
            if preferredInfo.genesisHash == nil {
                let locale = localizationManager?.selectedLocale
                let message = R.string.localizable.accountImportJsonNoNetwork(preferredLanguages: locale?.rLanguages)
                view?.setUploadWarning(message: message)
                return
            }

            if (try? Data(hexString: chainModelId)) != preferredInfo.genesisHash {
                let message = R.string.localizable
                    .accountImportWrongNetwork(preferredLanguages: selectedLocale.rLanguages)
                view?.setUploadWarning(message: message)
                return
            }
        }
    }
}
