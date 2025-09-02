import Foundation
import Foundation_iOS
import NovaCrypto

final class ExportMnemonicPresenter: CheckboxListPresenterTrait {
    weak var view: AccountCreateViewProtocol?
    let wireframe: ExportMnemonicWireframeProtocol
    let interactor: ExportMnemonicInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol
    let checkboxListViewModelFactory: CheckboxListViewModelFactory
    let mnemonicViewModelFactory: MnemonicViewModelFactory

    var checkboxView: CheckboxListViewProtocol? { view }
    var checkboxViewModels: [CheckBoxIconDetailsView.Model] = []

    private var wasActive: Bool = false
    private(set) var exportData: ExportMnemonicData?

    init(
        interactor: ExportMnemonicInteractorInputProtocol,
        wireframe: ExportMnemonicWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        checkboxListViewModelFactory: CheckboxListViewModelFactory,
        mnemonicViewModelFactory: MnemonicViewModelFactory
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
        self.checkboxListViewModelFactory = checkboxListViewModelFactory
        self.mnemonicViewModelFactory = mnemonicViewModelFactory
    }

    private func provideNotVisibleViewModel() {
        let mnemonicCardViewModel: HiddenMnemonicCardView.State = .mnemonicNotVisible(
            model: mnemonicViewModelFactory.createMnemonicCardHiddenModel()
        )

        view?.update(with: mnemonicCardViewModel)
    }

    private func provideVisibleViewModel(for mnemonic: IRMnemonicProtocol) {
        let mnemonicCardViewModel: HiddenMnemonicCardView.State = .mnemonicVisible(
            model: mnemonicViewModelFactory.createMnemonicCardViewModel(
                for: mnemonic.allWords()
            )
        )

        view?.update(with: mnemonicCardViewModel)
    }
}

extension ExportMnemonicPresenter: AccountCreatePresenterProtocol {
    func setup() {
        checkboxViewModels = checkboxListViewModelFactory.makeWarningsInitialViewModel(
            showingIcons: false,
            checkBoxTapped
        )

        updateCheckBoxListView()
        provideNotVisibleViewModel()
    }

    func activateAdvanced() {
        guard let exportData = exportData, let accountResponse = exportData.metaAccount.fetch(
            for: exportData.chain.accountRequest()
        ) else {
            return
        }

        let advancedSettings: AdvancedWalletSettings

        if exportData.chain.isEthereumBased {
            advancedSettings = AdvancedWalletSettings.ethereum(
                derivationPath: exportData.derivationPath
            )
        } else {
            let networkSettings = AdvancedNetworkTypeSettings(
                availableCryptoTypes: [accountResponse.cryptoType],
                selectedCryptoType: accountResponse.cryptoType,
                derivationPath: exportData.derivationPath
            )

            advancedSettings = AdvancedWalletSettings.substrate(settings: networkSettings)
        }

        wireframe.showAdvancedSettings(from: view, secretSource: .mnemonic(.appDefault), settings: advancedSettings)
    }

    func provideMnemonic() {
        if let mnemonic = exportData?.mnemonic {
            provideVisibleViewModel(for: mnemonic)
        }
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
                self?.interactor.fetchExportData()
            },
            onCancel: { [weak self] in
                self?.wireframe.close(view: self?.view)
            }
        )
    }

    func becomeInactive() {
        provideNotVisibleViewModel()
    }

    func continueTapped() {
        guard let exportData = exportData else {
            return
        }

        wireframe.openConfirmationForMnemonic(exportData.mnemonic, from: view)
    }
}

extension ExportMnemonicPresenter: ExportMnemonicInteractorOutputProtocol {
    func didReceive(exportData: ExportMnemonicData) {
        self.exportData = exportData
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}
