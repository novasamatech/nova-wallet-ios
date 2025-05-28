import Foundation
import Operation_iOS
import SubstrateSdk
import Foundation_iOS

final class GenericLedgerAccountSelectionPresenter {
    weak var view: GenericLedgerAccountSelectionViewProtocol?
    let wireframe: GenericLedgerAccountSelectionWireframeProtocol
    let interactor: GenericLedgerAccountSelectionInteractorInputProtocol
    let viewModelFactory: GenericLedgerAccountVMFactoryProtocol
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol

    private var availableSchemes: Set<GenericLedgerAddressScheme> = []
    private var chains: [ChainModel.Id: ChainModel] = [:]
    private var accounts: [GenericLedgerAccountModel] = []

    init(
        interactor: GenericLedgerAccountSelectionInteractorInputProtocol,
        wireframe: GenericLedgerAccountSelectionWireframeProtocol,
        viewModelFactory: GenericLedgerAccountVMFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func performLoadNext() {
        let index = accounts.count

        guard index <= UInt32.max else {
            return
        }

        view?.didStartLoading()

        interactor.loadAccounts(at: UInt32(index), schemes: availableSchemes)
    }

    private func addAccountViewModel(for account: GenericLedgerAccountModel) {
        let viewModel = viewModelFactory.createViewModel(
            for: account,
            locale: localizationManager.selectedLocale
        )

        view?.didAddAccount(viewModel: viewModel)
    }
}

extension GenericLedgerAccountSelectionPresenter: GenericLedgerAccountSelectionPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectAccount(in section: Int) {
        wireframe.showWalletCreate(from: view, index: UInt32(section))
    }

    func selectAddress(in section: Int, at index: Int) {
        guard let address = accounts[section].addresses[index].address else {
            return
        }

        // TODO: Present address here
    }

    func loadNext() {
        performLoadNext()
    }
}

extension GenericLedgerAccountSelectionPresenter: GenericLedgerAccountSelectionInteractorOutputProtocol {
    func didReceiveLedgerChain(changes: [DataProviderChange<ChainModel>]) {
        chains = changes.mergeToDict(chains)

        let newSchemes: Set<GenericLedgerAddressScheme> = chains.values.reduce(into: []) { accum, model in
            if model.isEthereumBased {
                accum.insert(.evm)
            } else {
                accum.insert(.substrate)
            }
        }

        if availableSchemes != newSchemes {
            view?.didClearAccounts()

            availableSchemes = newSchemes
            accounts = []

            performLoadNext()
        }
    }

    func didReceive(account: GenericLedgerAccountModel) {
        logger.debug("Did receive account: \(account)")

        if account.index == accounts.count {
            view?.didStopLoading()

            accounts.append(account)

            addAccountViewModel(for: account)
        }
    }
}
