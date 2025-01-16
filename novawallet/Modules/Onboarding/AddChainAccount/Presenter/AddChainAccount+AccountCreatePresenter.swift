import Foundation_iOS
extension AddChainAccount {
    final class AccountCreatePresenter: BaseAccountCreatePresenter {
        let metaAccountModel: MetaAccountModel
        let chainModelId: ChainModel.Id
        let isEthereumBased: Bool

        init(
            interactor: AccountCreateInteractorInputProtocol,
            wireframe: AccountCreateWireframeProtocol,
            metaAccountModel: MetaAccountModel,
            chainModelId: ChainModel.Id,
            isEthereumBased: Bool,
            localizationManager: LocalizationManagerProtocol,
            checkboxListViewModelFactory: CheckboxListViewModelFactory,
            mnemonicViewModelFactory: MnemonicViewModelFactory
        ) {
            self.metaAccountModel = metaAccountModel
            self.chainModelId = chainModelId
            self.isEthereumBased = isEthereumBased

            super.init(
                interactor: interactor,
                wireframe: wireframe,
                localizationManager: localizationManager,
                checkboxListViewModelFactory: checkboxListViewModelFactory,
                mnemonicViewModelFactory: mnemonicViewModelFactory
            )
        }

        private func getRequest(with mnemonic: String) -> ChainAccountImportMnemonicRequest? {
            if isEthereumBased {
                return ChainAccountImportMnemonicRequest(
                    mnemonic: mnemonic,
                    derivationPath: ethereumDerivationPath,
                    cryptoType: selectedEthereumCryptoType
                )

            } else {
                guard let cryptoType = selectedSubstrateCryptoType else { return nil }

                return ChainAccountImportMnemonicRequest(
                    mnemonic: mnemonic,
                    derivationPath: substrateDerivationPath,
                    cryptoType: cryptoType
                )
            }
        }

        // MARK: - Overrides

        override func processProceed() {
            let mnemonic = metadata?.mnemonic

            guard let phrase = mnemonic?.joined(separator: " "),
                  let request = getRequest(with: phrase) else { return }

            wireframe.confirm(
                from: view,
                request: request,
                metaAccountModel: metaAccountModel,
                chainModelId: chainModelId
            )
        }

        override func getAdvancedSettings() -> AdvancedWalletSettings? {
            if isEthereumBased {
                return .ethereum(derivationPath: ethereumDerivationPath)
            } else {
                guard let availableCrypto = availableCrypto else { return nil }

                let substrateSettings = AdvancedNetworkTypeSettings(
                    availableCryptoTypes: availableCrypto.availableCryptoTypes,
                    selectedCryptoType: selectedSubstrateCryptoType ?? availableCrypto.defaultCryptoType,
                    derivationPath: substrateDerivationPath
                )

                return .substrate(settings: substrateSettings)
            }
        }
    }
}
