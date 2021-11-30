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
        interactor.setup()
    }

    func prepareToDisplayMnemonic() {
        let alertTitle = R.string.localizable
            .commonNoScreenshotTitle_v2_2_0(preferredLanguages: selectedLocale.rLanguages)
        let alertMessage = R.string.localizable
            .commonNoScreenshotMessage_v2_2_0(preferredLanguages: selectedLocale.rLanguages)
        let proceedTitle = R.string.localizable
            .commonUnderstand(preferredLanguages: selectedLocale.rLanguages)
        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: selectedLocale.rLanguages)

        let proceedClosure = {
            self.view?.displayMnemonic()
            return
        }

        let cancelClosure = {
            self.view?.controller.navigationController?.popViewController(animated: true)
            return
        }

        let proceedAction = AlertPresentableAction(
            title: proceedTitle,
            style: .normal,
            handler: proceedClosure
        )

        let cancelAction = AlertPresentableAction(
            title: cancelTitle,
            style: .destructive,
            handler: cancelClosure
        )

        let viewModel = AlertPresentableViewModel(
            title: alertTitle,
            message: alertMessage,
            actions: [cancelAction, proceedAction],
            closeAction: nil
        )

        wireframe.present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )
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
    func didReceive(metadata: MetaAccountCreationMetadata) {
        view?.set(mnemonic: metadata.mnemonic)
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
    func applyLocalization() {}
}
