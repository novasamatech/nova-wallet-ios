import UIKit
import IrohaCrypto
import SoraFoundation

final class AccountCreatePresenter: BaseAccountCreatePresenter {
    let usernameSetup: UsernameSetupModel

    init(usernameSetup: UsernameSetupModel) {
        self.usernameSetup = usernameSetup
    }

    override func processProceed() {
        guard
            let cryptoType = selectedSubstrateCryptoType,
            let substrateViewModel = substrateDerivationPathViewModel,
            let ethereumViewModel = ethereumDerivationPathViewModel,
            let metadata = metadata
        else {
            return
        }

        guard substrateViewModel.inputHandler.completed else {
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(cryptoType)
            return
        }

        guard ethereumViewModel.inputHandler.completed else {
            view?.didValidateEthereumDerivationPath(.invalid)
            presentDerivationPathError(.ethereumEcdsa)
            return
        }

        let substrateDerivationPath = substrateDerivationPathViewModel?.inputHandler.value ?? ""

        let ethereumDerivationPath = ethereumViewModel.inputHandler.value.isEmpty ?
            DerivationPathConstants.defaultEthereum : ethereumViewModel.inputHandler.value

        let request = MetaAccountCreationRequest(
            username: usernameSetup.username,
            derivationPath: substrateDerivationPath,
            ethereumDerivationPath: ethereumDerivationPath,
            cryptoType: cryptoType
        )

        wireframe.confirm(from: view, request: request, metadata: metadata)
    }
}
