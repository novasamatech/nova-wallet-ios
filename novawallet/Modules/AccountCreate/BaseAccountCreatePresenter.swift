import Foundation
import SoraFoundation

class BaseAccountCreatePresenter {
    weak var view: AccountCreateViewProtocol?
    var wireframe: AccountCreateWireframeProtocol!
    var interactor: AccountCreateInteractorInputProtocol!

    internal var metadata: MetaAccountCreationMetadata?

    // MARK: - Unknown
}

extension BaseAccountCreatePresenter: AccountCreatePresenterProtocol {
    func setup() {
        // Display warning
        // If user agrees, setup interactor
        // If not, dismiss everything
        // TODO: Setup interactor
    }

    func activateAdvanced() {
        // TODO: fill after Ruslan finishes his part
    }

    func proceed() {
//        guard
//            let metadata = metadata
//        else {
//            return
//        }
//
//        // TODO: Get real values
//        let cryptoType: MultiassetCryptoType = .sr25519
//
//        let substrateDerivationPath = ""
//        let ethereumDerivationPath = DerivationPathConstants.defaultEthereum
//
//        let request = MetaAccountCreationRequest(
//            username: walletName,
//            derivationPath: substrateDerivationPath,
//            ethereumDerivationPath: ethereumDerivationPath,
//            cryptoType: cryptoType
//        )
//
//        wireframe.confirm(from: view, request: request, metadata: metadata)
    }
}

extension BaseAccountCreatePresenter: AccountCreateInteractorOutputProtocol {
    func didReceive(metadata _: MetaAccountCreationMetadata) {
        // TODO: Implement
    }

    func didReceiveMnemonicGeneration(error _: Error) {
        // TODO: Implement
    }
}

// MARK: - AdvancedDeleegate

// TODO: Implement after Ruslan finishes his part
// extension BaseAccountCreeatePresenter: AdvancedDeleegate

// MARK: - Localizable

extension BaseAccountCreatePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
//            applyCryptoTypeViewModel()
            // TODO: Do something or remove conformancee?
        }
    }
}
