import Foundation
import IrohaCrypto
import SubstrateSdk
import SoraFoundation

final class BackupMnemonicCardPresenter {
    weak var view: BackupMnemonicCardViewProtocol?
    let wireframe: BackupMnemonicCardWireframeProtocol
    let interactor: BackupMnemonicCardInteractor

    private var mnemonic: IRMnemonicProtocol?
    private var metaAccount: MetaAccountModel

    private let walletViewModelFactory = WalletAccountViewModelFactory()
    private let logger: LoggerProtocol
    private let localizationManager: LocalizationManagerProtocol

    init(
        interactor: BackupMnemonicCardInteractor,
        wireframe: BackupMnemonicCardWireframeProtocol,
        metaAccount: MetaAccountModel,
        localizationManager: LocalizationManager,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.metaAccount = metaAccount
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

// MARK: BackupMnemonicCardPresenterProtocol

extension BackupMnemonicCardPresenter: BackupMnemonicCardPresenterProtocol {
    func setup() {
        updateView()
    }

    func mnemonicCardTapped() {
        interactor.fetchMnemonic()
    }

    func advancedTapped() {
        wireframe.showAdvancedExport(
            from: view,
            with: metaAccount,
            chain: nil
        )
    }
}

// MARK: BackupMnemonicCardInteractorOutputProtocol

extension BackupMnemonicCardPresenter: BackupMnemonicCardInteractorOutputProtocol {
    func didReceive(mnemonic: IRMnemonicProtocol) {
        self.mnemonic = mnemonic

        updateView()
    }

    func didReceive(error: Error) {
        logger.error("Did receive error: \(error)")

        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.dataCorruption,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}

// MARK: Private

private extension BackupMnemonicCardPresenter {
    func updateView() {
        guard let walletViewModel = try? walletViewModelFactory.createDisplayViewModel(from: metaAccount) else {
            return
        }

        view?.update(with:
            .init(
                walletViewModel: walletViewModel,
                state: {
                    if let mnemonic {
                        .mnemonicVisible(words: mnemonic.allWords())
                    } else {
                        .mnemonicNotVisible
                    }
                }()
            )
        )
    }
}

// MARK: Localizable

extension BackupMnemonicCardPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}
