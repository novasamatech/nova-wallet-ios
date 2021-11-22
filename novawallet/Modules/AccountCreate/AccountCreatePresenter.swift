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

        var derivationPathCheckError = false
        if !substrateViewModel.inputHandler.completed {
            derivationPathCheckError = true
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(cryptoType)
        }

        if !ethereumViewModel.inputHandler.completed {
            view?.didValidateEthereumDerivationPath(.invalid)
            if !derivationPathCheckError {
                presentDerivationPathError(.ethereumEcdsa)
                derivationPathCheckError = true
            }
        }

        guard !derivationPathCheckError else { return }

        let substrateDerivationPath = substrateViewModel.inputHandler.value

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
