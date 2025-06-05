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

    private var availableSchemes: Set<HardwareWalletAddressScheme> = []
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
}

private extension GenericLedgerAccountSelectionPresenter {
    private func provideWarningIfNeeded(for account: GenericLedgerAccountModel) {
        let hasMissingEvm = account.addresses.contains(where: { $0.scheme == .evm && $0.accountId == nil })

        if hasMissingEvm {
            let viewModel = TitleWithSubtitleViewModel(
                title: R.string.localizable.genericLedgerUpdateTitle(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ),
                subtitle: R.string.localizable.genericLedgerNoEvmMessage(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                )
            )

            view?.didReceive(warningViewModel: viewModel, canLoadMore: true)
        }
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
        let account = accounts[section]

        let schemes = account.addresses.compactMap { address in
            address.accountId != nil ? address.scheme : nil
        }

        let model = GenericLedgerWalletConfirmModel(
            index: account.index,
            schemes: schemes
        )

        wireframe.showWalletCreate(from: view, model: model)
    }

    func selectAddress(in section: Int, at index: Int) {
        let model = accounts[section].addresses[index]

        guard
            let view,
            let address = model.address else {
            return
        }

        wireframe.presentHardwareAddressOptions(
            from: view,
            address: address,
            scheme: model.scheme,
            locale: localizationManager.selectedLocale
        )
    }

    func loadNext() {
        performLoadNext()
    }
}

extension GenericLedgerAccountSelectionPresenter: GenericLedgerAccountSelectionInteractorOutputProtocol {
    func didReceiveLedgerChain(changes: [DataProviderChange<ChainModel>]) {
        chains = changes.mergeToDict(chains)

        let newSchemes: Set<HardwareWalletAddressScheme> = chains.values.reduce(into: []) { accum, model in
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

            if accounts.isEmpty {
                provideWarningIfNeeded(for: account)
            }

            accounts.append(account)

            addAccountViewModel(for: account)
        }
    }

    func didReceive(error: GenericLedgerAccountInteractorError) {
        logger.error("Error: \(error)")

        switch error {
        case .accountFetchFailed:
            wireframe.presentRequestStatus(
                on: view,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                self?.performLoadNext()
            }
        }
    }
}
