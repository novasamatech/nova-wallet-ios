import SwiftUI
extension AddChainAccount {
    final class AccountCreatePresenter: BaseAccountCreatePresenter {
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

            super.init()

            displaySubstrate = !isEthereumBased
            displayEthereum = isEthereumBased
        }

        private func prooceedWithSubstrate() {
            guard
                let cryptoType = selectedCryptoType,
                let substrateViewModel = substrateDerivationPathViewModel,
                let metadata = metadata
            else {
                return
            }

            guard substrateViewModel.inputHandler.completed else {
                view?.didValidateSubstrateDerivationPath(.invalid)
                presentDerivationPathError(cryptoType)
                return
            }

            let substrateDerivationPath = substrateDerivationPathViewModel?.inputHandler.value ?? ""

            let request = ChainAccountImportMnemonicRequest(
                mnemonic: metadata.mnemonic.joined(separator: " "),
                derivationPath: substrateDerivationPath,
                cryptoType: cryptoType
            )

            wireframe.confirm(
                from: view,
                request: request,
                metaAccountModel: metaAccountModel,
                chainModelId: chainModelId
            )
        }

        private func proceedWithEthereum() {
            guard
                let ethereumViewModel = ethereumDerivationPathViewModel,
                let metadata = metadata
            else {
                return
            }

            guard ethereumViewModel.inputHandler.completed else {
                view?.didValidateEthereumDerivationPath(.invalid)
                presentDerivationPathError(.ethereumEcdsa)
                return
            }

            let ethereumDerivationPath = ethereumViewModel.inputHandler.value.isEmpty ?
                DerivationPathConstants.defaultEthereum : ethereumViewModel.inputHandler.value

            let request = ChainAccountImportMnemonicRequest(
                mnemonic: metadata.mnemonic.joined(separator: " "),
                derivationPath: ethereumDerivationPath,
                cryptoType: .ethereumEcdsa
            )

            wireframe.confirm(
                from: view,
                request: request,
                metaAccountModel: metaAccountModel,
                chainModelId: chainModelId
            )
        }

        override func processProceed() {
            if isEthereumBased {
                proceedWithEthereum()
            } else {
                prooceedWithSubstrate()
            }
        }
    }
}
