import Foundation
import IrohaCrypto
import SubstrateSdk
import SoraFoundation

final class BackupMnemonicCardPresenter {
    weak var view: BackupMnemonicCardViewProtocol?
    let wireframe: BackupMnemonicCardWireframeProtocol
    let interactor: BackupMnemonicCardInteractor

    private var mnemonic: IRMnemonicProtocol?
    private var chain: ChainModel?
    private let metaAccount: MetaAccountModel

    private let walletViewModelFactory = WalletAccountViewModelFactory()
    private let networkViewModelFactory: NetworkViewModelFactoryProtocol
    private let logger: LoggerProtocol
    private let localizationManager: LocalizationManagerProtocol

    init(
        interactor: BackupMnemonicCardInteractor,
        wireframe: BackupMnemonicCardWireframeProtocol,
        metaAccount: MetaAccountModel,
        chain: ChainModel?,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        localizationManager: LocalizationManager,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.metaAccount = metaAccount
        self.chain = chain
        self.networkViewModelFactory = networkViewModelFactory
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
            chain: chain
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
                networkViewModel: {
                    if let chain {
                        networkViewModelFactory.createViewModel(from: chain)
                    } else {
                        .none
                    }
                }(),
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
