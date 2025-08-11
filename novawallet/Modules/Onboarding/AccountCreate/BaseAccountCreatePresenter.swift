import Foundation
import Foundation_iOS

class BaseAccountCreatePresenter: CheckboxListPresenterTrait {
    weak var view: AccountCreateViewProtocol?
    let wireframe: AccountCreateWireframeProtocol
    let interactor: AccountCreateInteractorInputProtocol
    let checkboxListViewModelFactory: CheckboxListViewModelFactory
    let mnemonicViewModelFactory: MnemonicViewModelFactory

    var checkboxView: CheckboxListViewProtocol? { view }
    var checkboxViewModels: [CheckBoxIconDetailsView.Model] = []

    let localizationManager: LocalizationManagerProtocol

    private(set) var wasActive: Bool = false

    private(set) var metadata: MetaAccountCreationMetadata?
    private(set) var availableCrypto: MetaAccountAvailableCryptoTypes?

    private(set) var selectedSubstrateCryptoType: MultiassetCryptoType?
    private(set) var substrateDerivationPath: String = ""

    internal let selectedEthereumCryptoType: MultiassetCryptoType = .ethereumEcdsa
    private(set) var ethereumDerivationPath: String = DerivationPathConstants.defaultEthereum

    init(
        interactor: AccountCreateInteractorInputProtocol,
        wireframe: AccountCreateWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        checkboxListViewModelFactory: CheckboxListViewModelFactory,
        mnemonicViewModelFactory: MnemonicViewModelFactory
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.checkboxListViewModelFactory = checkboxListViewModelFactory
        self.mnemonicViewModelFactory = mnemonicViewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private functions

    private func provideNotVisibleViewModel() {
        let mnemonicCardViewModel: HiddenMnemonicCardView.State = .mnemonicNotVisible(
            model: mnemonicViewModelFactory.createMnemonicCardHiddenModel()
        )

        view?.update(with: mnemonicCardViewModel)
    }

    private func provideVisibleViewModel(for metadata: MetaAccountCreationMetadata) {
        let mnemonicCardViewModel: HiddenMnemonicCardView.State = .mnemonicVisible(
            model: mnemonicViewModelFactory.createMnemonicCardViewModel(
                for: metadata.mnemonic
            )
        )

        view?.update(with: mnemonicCardViewModel)
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
        checkboxViewModels = checkboxListViewModelFactory.makeWarningsInitialViewModel(
            showingIcons: false,
            checkBoxTapped
        )

        updateCheckBoxListView()
        provideNotVisibleViewModel()

        interactor.setup()
    }

    func becomeActive() {
        guard !wasActive else {
            return
        }

        wasActive = true

        wireframe.presentBackupManualWarning(
            from: view,
            locale: localizationManager.selectedLocale,
            onProceed: { [weak self] in
                self?.interactor.provideMnemonic()
            },
            onCancel: { [weak self] in
                self?.wireframe.cancelFlow(from: self?.view)
            }
        )
    }

    func becomeInactive() {
        provideNotVisibleViewModel()
    }

    func activateAdvanced() {
        guard let settings = getAdvancedSettings() else {
            return
        }

        provideNotVisibleViewModel()

        wireframe.showAdvancedSettings(
            from: view,
            secretSource: .mnemonic(.appDefault),
            settings: settings,
            delegate: self
        )
    }

    func provideMnemonic() {
        if let metadata {
            provideVisibleViewModel(for: metadata)
        }
    }

    func continueTapped() {
        processProceed()
    }
}

// MARK: - AccountCreateInteractorOutputProtocol

extension BaseAccountCreatePresenter: AccountCreateInteractorOutputProtocol {
    func didReceive(availableCrypto: MetaAccountAvailableCryptoTypes) {
        self.availableCrypto = availableCrypto
        selectedSubstrateCryptoType = availableCrypto.defaultCryptoType
    }

    func didReceive(metadata: MetaAccountCreationMetadata) {
        self.metadata = metadata
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
