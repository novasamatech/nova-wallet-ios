import Foundation
import SoraFoundation

class BaseAccountCreatePresenter {
    weak var view: AccountCreateViewProtocol?
    var wireframe: AccountCreateWireframeProtocol!
    var interactor: AccountCreateInteractorInputProtocol!

    private let localizationManager: LocalizationManagerProtocol

    private(set) var metadata: MetaAccountCreationMetadata?

    private(set) var selectedSubstrateCryptoType: MultiassetCryptoType?
    private(set) var substrateDerivationPath: String = ""

    internal let selectedEthereumCryptoType: MultiassetCryptoType = .ethereumEcdsa
    private(set) var ethereumDerivationPath: String = DerivationPathConstants.defaultEthereum

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    // MARK: - Private functions

    private func createCancelAction() -> AlertPresentableAction {
        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: localizationManager.selectedLocale.rLanguages)

        let cancelClosure = {
            self.wireframe.cancelFlow(from: self.view)
            return
        }

        return AlertPresentableAction(
            title: cancelTitle,
            style: .destructive,
            handler: cancelClosure
        )
    }

    private func createProceedAction() -> AlertPresentableAction {
        let locale = localizationManager.selectedLocale

        let proceedTitle = R.string.localizable
            .commonUnderstand(preferredLanguages: locale.rLanguages)

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
        let locale = localizationManager.selectedLocale

        let alertTitle = R.string.localizable
            .commonNoScreenshotTitle_v2_2_0(preferredLanguages: locale.rLanguages)
        let alertMessage = R.string.localizable
            .commonNoScreenshotMessage_v2_2_0(preferredLanguages: locale.rLanguages)

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

    // MARK: - Processing

    internal func getAdvancedSettings() -> AdvancedWalletSettings? {
        fatalError("This function should be overriden")
    }

    internal func processProceed() {
        fatalError("This function should be overriden")
    }
}

// MARK: - AccountCreatePresenterProtocol

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
        processProceed()
    }
}

// MARK: - AccountCreateInteractorOutputProtocol

extension BaseAccountCreatePresenter: AccountCreateInteractorOutputProtocol {
    func didReceive(metadata: MetaAccountCreationMetadata) {
        self.metadata = metadata
        selectedSubstrateCryptoType = metadata.defaultCryptoType
        view?.set(mnemonic: metadata.mnemonic)
    }

    func didReceiveMnemonicGeneration(error: Error) {
        let locale = localizationManager.selectedLocale

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
    }
}

// MARK: - AdvancedDeleegate

extension BaseAccountCreatePresenter: AdvancedWalletSettingsDelegate {
    func didReceiveNewAdvanced(walletSettings: AdvancedWalletSettings) {
        switch walletSettings {
        case let .substrate(settings):
            selectedSubstrateCryptoType = settings.selectedCryptoType
            substrateDerivationPath = settings.derivationPath ?? ""

        case let .ethereum(derivationPath):
            ethereumDerivationPath = derivationPath ?? ""

        case let .combined(substrateSettings, ethereumDerivationPath):
            selectedSubstrateCryptoType = substrateSettings.selectedCryptoType
            substrateDerivationPath = substrateSettings.derivationPath ?? ""
            self.ethereumDerivationPath = ethereumDerivationPath ?? ""
        }
    }
}
