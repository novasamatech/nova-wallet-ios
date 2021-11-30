import Foundation
import SoraFoundation

class BaseAccountCreatePresenter {
    weak var view: AccountCreateViewProtocol?
    var wireframe: AccountCreateWireframeProtocol!
    var interactor: AccountCreateInteractorInputProtocol!

    private(set) var metadata: MetaAccountCreationMetadata?

    private(set) var selectedSubstrateCryptoType: MultiassetCryptoType?
    private(set) var substrateDerivationPath: String?

    private let selectedEthereumCryptoType: MultiassetCryptoType = .ethereumEcdsa
    private(set) var ethereumDerivationPath: String = DerivationPathConstants.defaultEthereum

//    private(set) var sourceViewModel: InputViewModelProtocol?
//    private(set) var usernameViewModel: InputViewModelProtocol?
//    private(set) var passwordViewModel: InputViewModelProtocol?

    // MARK: - Private functions

    private func createCancelAction() -> AlertPresentableAction {
        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: selectedLocale.rLanguages)

        let cancelClosure = {
            self.view?.controller.navigationController?.popViewController(animated: true)
            return
        }

        return AlertPresentableAction(
            title: cancelTitle,
            style: .destructive,
            handler: cancelClosure
        )
    }

    private func createProceedAction() -> AlertPresentableAction {
        let proceedTitle = R.string.localizable
            .commonUnderstand(preferredLanguages: selectedLocale.rLanguages)

        let proceedClosure = {
            self.view?.displayMnemonic()
            return
        }

        return AlertPresentableAction(
            title: proceedTitle,
            style: .normal,
            handler: proceedClosure
        )
    }

    private func createWarningViewModel() -> AlertPresentableViewModel {
        let alertTitle = R.string.localizable
            .commonNoScreenshotTitle_v2_2_0(preferredLanguages: selectedLocale.rLanguages)
        let alertMessage = R.string.localizable
            .commonNoScreenshotMessage_v2_2_0(preferredLanguages: selectedLocale.rLanguages)

        let cancelAction = createCancelAction()
        let proceedAction = createProceedAction()
        let actions = [cancelAction, proceedAction]

        return AlertPresentableViewModel(
            title: alertTitle,
            message: alertMessage,
            actions: actions,
            closeAction: nil
        )
    }

    private func getAdvancedSettings() -> AdvancedWalletSettings? {
        guard let metadata = metadata else {
            return nil
        }

        let substrateSettings = AdvancedNetworkTypeSettings(
            availableCryptoTypes: metadata.availableCryptoTypes,
            selectedCryptoType: selectedSubstrateCryptoType ?? metadata.defaultCryptoType,
            derivationPath: substrateDerivationPath
        )

        return .combined(
            substrateSettings: substrateSettings,
            ethereumDerivationPath: ethereumDerivationPath
        )
    }
}

extension BaseAccountCreatePresenter: AccountCreatePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func prepareToDisplayMnemonic() {
        let viewModel = createWarningViewModel()

        wireframe.present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )
    }

    func activateAdvanced() {
        guard let settings = getAdvancedSettings() else {
            return
        }

        wireframe.showAdvancedSettings(
            from: view,
            secretSource: .mnemonic,
            settings: settings,
            delegate: self
        )
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
        self.metadata = metadata
        view?.set(mnemonic: metadata.mnemonic)
    }

    func didReceiveMnemonicGeneration(error _: Error) {
        // TODO: Implement
    }
}

// MARK: - AdvancedDeleegate

extension BaseAccountCreatePresenter: AdvancedWalletSettingsDelegate {
    func didReceiveNewAdvanced(walletSettings: AdvancedWalletSettings) {
        guard case let .combined(substrateSettings, ethereumDerivationPath) = walletSettings else {
            return
        }

        selectedSubstrateCryptoType = substrateSettings.selectedCryptoType
        substrateDerivationPath = substrateSettings.derivationPath
        self.ethereumDerivationPath = ethereumDerivationPath
    }
}

// MARK: - Localizable

extension BaseAccountCreatePresenter: Localizable {
    func applyLocalization() {}
}
