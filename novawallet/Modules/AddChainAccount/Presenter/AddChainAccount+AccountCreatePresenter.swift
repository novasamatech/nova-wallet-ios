import SoraFoundation
extension AddChainAccount {
    final class AccountCreatePresenter: BaseAccountCreatePresenter {
        let metaAccountModel: MetaAccountModel
        let chainModelId: ChainModel.Id
        let isEthereumBased: Bool

        init(
            metaAccountModel: MetaAccountModel,
            chainModelId: ChainModel.Id,
            isEthereumBased: Bool,
            localizationManager: LocalizationManagerProtocol
        ) {
            self.metaAccountModel = metaAccountModel
            self.chainModelId = chainModelId
            self.isEthereumBased = isEthereumBased

            super.init(localizationManager: localizationManager)
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
            guard let mnemonic = metadata?.mnemonic.joined(separator: " "),
                  let request = getRequest(with: mnemonic) else { return }

            wireframe.confirm(
                from: view,
                request: request,
                metaAccountModel: metaAccountModel,
                chainModelId: chainModelId
            )
        }

        override func getAdvancedSettings() -> AdvancedWalletSettings? {
            guard let metadata = metadata else { return nil }

            if isEthereumBased {
                return .ethereum(derivationPath: ethereumDerivationPath)

            } else {
                let substrateSettings = AdvancedNetworkTypeSettings(
                    availableCryptoTypes: metadata.availableCryptoTypes,
                    selectedCryptoType: selectedSubstrateCryptoType ?? metadata.defaultCryptoType,
                    derivationPath: substrateDerivationPath
                )

                return .substrate(settings: substrateSettings)
            }
        }
    }
}
