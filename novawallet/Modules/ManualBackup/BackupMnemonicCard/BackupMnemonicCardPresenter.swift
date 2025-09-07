import Foundation
import NovaCrypto
import SubstrateSdk
import Foundation_iOS

final class BackupMnemonicCardPresenter {
    weak var view: BackupMnemonicCardViewProtocol?
    let wireframe: BackupMnemonicCardWireframeProtocol
    let interactor: BackupMnemonicCardInteractor

    private var mnemonic: IRMnemonicProtocol?
    private var chain: ChainModel?
    private let metaAccount: MetaAccountModel

    private let walletViewModelFactory = WalletAccountViewModelFactory()
    private let networkViewModelFactory: NetworkViewModelFactoryProtocol
    private let mnemonicViewModelFactory: MnemonicViewModelFactory
    private let logger: LoggerProtocol

    init(
        interactor: BackupMnemonicCardInteractor,
        wireframe: BackupMnemonicCardWireframeProtocol,
        metaAccount: MetaAccountModel,
        chain: ChainModel?,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        mnemonicViewModelFactory: MnemonicViewModelFactory,
        localizationManager: LocalizationManager,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.metaAccount = metaAccount
        self.chain = chain
        self.networkViewModelFactory = networkViewModelFactory
        self.mnemonicViewModelFactory = mnemonicViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
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

        if !wireframe.present(error: error, from: view, locale: selectedLocale) {
            _ = wireframe.present(
                error: CommonError.dataCorruption,
                from: view,
                locale: selectedLocale
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
                mnemonicCardState: {
                    if let mnemonic {
                        .mnemonicVisible(
                            model: mnemonicViewModelFactory.createMnemonicCardViewModel(
                                for: mnemonic.allWords()
                            )
                        )
                    } else {
                        .mnemonicNotVisible(
                            model: mnemonicViewModelFactory.createMnemonicCardHiddenModel()
                        )
                    }
                }()
            )
        )
    }

    func createCardTitle() -> NSAttributedString {
        NSAttributedString.coloredItems(
            [
                R.string(preferredLanguages: selectedLocale.rLanguages
                ).localizable.mnemonicCardRevealedHeaderMessageHighlighted()
            ],
            formattingClosure: { items in
                R.string(preferredLanguages: selectedLocale.rLanguages
                ).localizable.mnemonicCardRevealedHeaderMessage(items[0])
            },
            color: R.color.colorTextPrimary()!
        )
    }
}

// MARK: Localizable

extension BackupMnemonicCardPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}
