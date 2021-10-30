import Foundation
import RobinHood
import IrohaCrypto
import SoraFoundation

final class AccountManagementPresenter {
    weak var view: AccountManagementViewProtocol?
    var wireframe: AccountManagementWireframeProtocol!
    var interactor: AccountManagementInteractorInputProtocol!

    let viewModelFactory: ChainAccountViewModelFactoryProtocol
    let walletId: String
    let logger: LoggerProtocol?

    private var wallet: MetaAccountModel?
    private var chains: [ChainModel.Id: ChainModel] = [:]
    private var viewModel: ChainAccountListViewModel = []
    private var polkascanExplorers: [String: String] = [:]
    private var subscanExplorers: [String: String] = [:]

    init(
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        walletId: String,
        logger: LoggerProtocol? = nil
    ) {
        self.viewModelFactory = viewModelFactory
        self.walletId = walletId
        self.logger = logger
    }

    // MARK: - Updating functions

    private func updateChainViewModels() {
        guard let wallet = wallet else { return }

        viewModel = viewModelFactory.createViewModel(from: wallet, chains: chains, for: selectedLocale)
        view?.reload()
    }

    private func updateNameViewModel() {
        guard let wallet = wallet else { return }

        let processor = ByteLengthProcessor.username
        let processedUsername = processor.process(text: wallet.name)

        let inputHandling = InputHandler(
            value: processedUsername,
            predicate: NSPredicate.notEmpty,
            processor: processor
        )

        let nameViewModel = InputViewModel(inputHandler: inputHandling)
        nameViewModel.inputHandler.addObserver(self)

        view?.set(nameViewModel: nameViewModel)
    }

    // MARK: - Actions

    private func activateCreateAccount(for chainModel: ChainModel) {
        guard let view = view,
              let wallet = wallet
        else { return }

        wireframe.showCreateAccount(
            from: view,
            wallet: wallet,
            chainId: chainModel.chainId,
            isEthereumBased: chainModel.isEthereumBased
        )
    }

    private func activateImportAccount(for chainModel: ChainModel) {
        guard let view = view,
              let wallet = wallet
        else { return }

        wireframe.showImportAccount(
            from: view,
            wallet: wallet,
            chainId: chainModel.chainId,
            isEthereumBased: chainModel.isEthereumBased
        )
    }

    private func displayNoAddressActions(for chain: ChainModel) {
        let title = R.string.localizable.accountNotFoundActionsTitle(
            chain.name,
            preferredLanguages: selectedLocale.rLanguages
        )

        var actions: [AlertPresentableAction] = []

        let createAccountTitle = R.string.localizable
            .accountCreateTitle(preferredLanguages: selectedLocale.rLanguages)
        let createAccountAction = AlertPresentableAction(title: createAccountTitle) { [weak self] in
            self?.activateCreateAccount(for: chain)
        }

        actions.append(createAccountAction)

        let importAccountTitle = R.string.localizable
            .accountImportTitle(preferredLanguages: selectedLocale.rLanguages)
        let importAccountAction = AlertPresentableAction(title: importAccountTitle) { [weak self] in
            self?.activateImportAccount(for: chain)
        }

        actions.append(importAccountAction)

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: selectedLocale.rLanguages)

        let actionsViewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: closeTitle
        )

        wireframe.present(
            viewModel: actionsViewModel,
            style: .actionSheet,
            from: view
        )
    }

    private func displayEthereumAddressActions(
        for chain: ChainModel,
        viewModel: ChainAccountViewModelItem
    ) {
        guard let address = viewModel.address else { return }
        var title = address

        let offset = title.count / 2
        title.insert(
            contentsOf: String.returnKey,
            at: title.index(title.startIndex, offsetBy: offset)
        )

        var actions: [AlertPresentableAction] = []

        let copyTitle = R.string.localizable
            .commonCopyAddress(preferredLanguages: selectedLocale.rLanguages)
        let copyAction = AlertPresentableAction(title: copyTitle) { [weak self] in
            self?.copyAddress(address)
        }

        actions.append(copyAction)

        let createAccountTitle = R.string.localizable
            .accountCreateTitle(preferredLanguages: selectedLocale.rLanguages)
        let createAccountAction = AlertPresentableAction(title: createAccountTitle) { [weak self] in
            self?.activateCreateAccount(for: chain)
        }

        actions.append(createAccountAction)

        let importAccountTitle = R.string.localizable
            .accountImportTitle(preferredLanguages: selectedLocale.rLanguages)
        let importAccountAction = AlertPresentableAction(title: importAccountTitle) { [weak self] in
            self?.activateImportAccount(for: chain)
        }

        actions.append(importAccountAction)

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: selectedLocale.rLanguages)

        let actionsViewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: closeTitle
        )

        wireframe.present(
            viewModel: actionsViewModel,
            style: .actionSheet,
            from: view
        )
    }

    private func displaySubstrateAddressActions(
        for chain: ChainModel,
        viewModel: ChainAccountViewModelItem
    ) {
        guard let address = viewModel.address else { return }
        var title = address

        let offset = title.count / 2
        title.insert(
            contentsOf: String.returnKey,
            at: title.index(title.startIndex, offsetBy: offset)
        )

        var actions: [AlertPresentableAction] = []

        let copyTitle = R.string.localizable
            .commonCopyAddress(preferredLanguages: selectedLocale.rLanguages)
        let copyAction = AlertPresentableAction(title: copyTitle) { [weak self] in
            self?.copyAddress(address)
        }

        actions.append(copyAction)

        if let url = polkascanURL(for: chain.name, address: address) {
            let polkascanTitle = R.string.localizable
                .transactionDetailsViewPolkascan(preferredLanguages: selectedLocale.rLanguages)

            let polkascanAction = AlertPresentableAction(title: polkascanTitle) { [weak self] in
                if let view = self?.view {
                    self?.wireframe.showWeb(url: url, from: view, style: .automatic)
                }
            }

            actions.append(polkascanAction)
        }

        if let url = subscanURL(for: chain.name, address: address) {
            let subscanTitle = R.string.localizable
                .transactionDetailsViewSubscan(preferredLanguages: selectedLocale.rLanguages)
            let subscanAction = AlertPresentableAction(title: subscanTitle) { [weak self] in
                if let view = self?.view {
                    self?.wireframe.showWeb(url: url, from: view, style: .automatic)
                }
            }

            actions.append(subscanAction)
        }

        let createAccountTitle = R.string.localizable
            .accountCreateTitle(preferredLanguages: selectedLocale.rLanguages)
        let createAccountAction = AlertPresentableAction(title: createAccountTitle) { [weak self] in
            self?.activateCreateAccount(for: chain)
        }

        actions.append(createAccountAction)

        let importAccountTitle = R.string.localizable
            .accountImportTitle(preferredLanguages: selectedLocale.rLanguages)
        let importAccountAction = AlertPresentableAction(title: importAccountTitle) { [weak self] in
            self?.activateImportAccount(for: chain)
        }

        actions.append(importAccountAction)

        // FIXME: Pack change accounts item under one sheet
        //        let changeAccountTitle = R.string.localizable
        //            .accountActionsChangeTitle(preferredLanguages: selectedLocale.rLanguages)
        //        let changeAccountAction = AlertPresentableAction(title: changeAccountTitle) { [weak self] in
        //            print("Change account")
        //            // TODO: display another actions view?
        //        }
        //
        //        actions.append(changeAccountAction)

        // TODO: Turn on export
        // TODO: display another actions view
        //        let exportAccountTitle = R.string.localizable
        //            .commonExport(preferredLanguages: selectedLocale.rLanguages)
        //        let exportAction = AlertPresentableAction(title: exportAccountTitle) { [weak self] in
        //            print("Export account")
        //        }

        //        actions.append(exportAction)

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: selectedLocale.rLanguages)

        let actionsViewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: closeTitle
        )

        wireframe.present(
            viewModel: actionsViewModel,
            style: .actionSheet,
            from: view
        )
    }

    // MARK: - Utility functions

    private func polkascanURL(for chainName: String, address: String) -> URL? {
        guard let urlString = polkascanExplorers[chainName] else { return nil }
        return URL(string: "\(urlString)\(address)")
    }

    private func subscanURL(for chainName: String, address: String) -> URL? {
        guard let urlString = subscanExplorers[chainName] else { return nil }
        return URL(string: "\(urlString)\(address)")
    }

    private func copyAddress(_ address: String) {
        UIPasteboard.general.string = address

        let locale = localizationManager?.selectedLocale
        let title = R.string.localizable.commonCopied(preferredLanguages: locale?.rLanguages)
        wireframe.presentSuccessNotification(title, from: view)
    }

    private func generateExplorers() {
        let polkascanExplorers: [String: String] = [
            "Polkadot": "https://polkascan.io/polkadot/account/",
            "Kusama": "https://polkascan.io/kusama/account/"
        ]

        let subscanExplorers: [String: String] = [
            "Polkadot": "https://polkadot.subscan.io/account/",
            "Kusama": "https://kusama.subscan.io/account/",
            "Westend": "https://westend.subscan.io/account/",
            "Calamari": "https://calamari.subscan.io/account/",
            "Moonriver": "https://moonriver.subscan.io/account/",
            "Statemine": "https://statemine.subscan.io/account/",
            "Shiden": "https://shiden.subscan.io/account/",
            "Bifrost": "https://bifrost.subscan.io/account/",
            "KILT Spiritnet": "https://spiritnet.subscan.io/account/",
            "Karura": "https://karura.subscan.io/account/",
            "Khala": "https://khala.subscan.io/account/"
        ]

        self.polkascanExplorers = polkascanExplorers
        self.subscanExplorers = subscanExplorers
    }
}

extension AccountManagementPresenter: AccountManagementPresenterProtocol {
    func setup() {
        generateExplorers()
        interactor.setup(walletId: walletId)
    }

    func numberOfSections() -> Int {
        viewModel.count
    }

    func numberOfItems(in section: Int) -> Int {
        viewModel[section].chainAccounts.count
    }

    func item(at indexPath: IndexPath) -> ChainAccountViewModelItem {
        let section = viewModel[indexPath.section]
        let viewModels = section.chainAccounts
        return viewModels[indexPath.row]
    }

    func titleForSection(_ section: Int) -> LocalizableResource<String> {
        viewModel[section].section.title
    }

    func activateDetails(at indexPath: IndexPath) {
        selectItem(at: indexPath)
    }

    func selectItem(at indexPath: IndexPath) {
        let viewModel = viewModel[indexPath.section]
            .chainAccounts[indexPath.row]

        guard let chainModel = chains[viewModel.chainId] else { return }

        if viewModel.address == nil {
            // Case 1: address not found
            displayNoAddressActions(for: chainModel)
        } else if chainModel.isEthereumBased {
            // Case 2: ethereum address found
            displayEthereumAddressActions(for: chainModel, viewModel: viewModel)
        } else {
            // Case 3: substrate address found
            displaySubstrateAddressActions(for: chainModel, viewModel: viewModel)
        }
    }

    func finalizeName() {
        interactor.flushPendingName()
    }
}

// MARK: - Interactor-to-Presenter functions

extension AccountManagementPresenter: AccountManagementInteractorOutputProtocol {
    func didReceiveWallet(_ result: Result<MetaAccountModel?, Error>) {
        switch result {
        case let .success(wallet):
            guard let wallet = wallet else {
                logger?.error("Did find no wallets with Id: \(walletId)")
                return
            }

            self.wallet = wallet
            updateChainViewModels()
            updateNameViewModel()

        case let .failure(error):
            logger?.error("Did receive wallet fetch error: \(error)")
        }
    }

    func didReceiveChains(_ result: Result<[ChainModel.Id: ChainModel], Error>) {
        switch result {
        case let .success(chains):
            self.chains = chains
            updateChainViewModels()

        case let .failure(error):
            logger?.error("Did receive chains fetch error: \(error)")
        }
    }

    func didSaveWalletName(_ result: Result<String, Error>) {
        switch result {
        case let .success(walletName):
            logger?.debug("Did save new wallet name: \(walletName)")

        case let .failure(error):
            logger?.error("Did receive wallet save error: \(error)")

            if !wireframe.present(error: error, from: view, locale: selectedLocale) {
                _ = wireframe.present(
                    error: CommonError.undefined,
                    from: view,
                    locale: selectedLocale
                )
            }
        }
    }
}

// MARK: - InputHandlingObserver

extension AccountManagementPresenter: InputHandlingObserver {
    func didChangeInputValue(_ handler: InputHandling, from _: String) {
        if handler.completed {
            let newName = handler.normalizedValue
            interactor.save(name: newName, walletId: walletId)
        }
    }
}

// MARK: - Localizable

extension AccountManagementPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateChainViewModels()
        }
    }
}
