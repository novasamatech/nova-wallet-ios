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

    private func updateWalletType() {
        guard let wallet = wallet else {
            return
        }

        let walletType = WalletsListSectionViewModel.SectionType(walletType: wallet.type)
        view?.set(walletType: walletType)
    }

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

    // MARK: - Bottom sheet display for watch only type

    private func displayWatchOnlyNoAddressActions(for chain: ChainModel) {
        guard let view = view else {
            return
        }

        let addAction = createAccountAddAction(for: chain, walletType: .watchOnly)

        let actions: [ChainAddressDetailsAction] = [addAction]

        let model = ChainAddressDetailsModel(
            address: nil,
            chainName: chain.name,
            chainIcon: chain.icon,
            actions: actions
        )

        wireframe.presentChainAddressDetails(from: view, model: model)
    }

    private func displayWatchOnlyExistingAddressActions(
        for chain: ChainModel,
        viewModel: ChainAccountViewModelItem
    ) {
        guard let view = view, let address = viewModel.address else {
            return
        }

        var actions: [ChainAddressDetailsAction] = []

        let copyAction = createCopyAction(for: address)
        actions.append(copyAction)

        let explorerActions = createExplorerActions(for: chain, address: address)

        actions.append(contentsOf: explorerActions)

        let changeAccountAction = createAccountChangeAction(for: chain, walletType: .watchOnly)
        actions.append(changeAccountAction)

        let model = ChainAddressDetailsModel(
            address: viewModel.address,
            chainName: chain.name,
            chainIcon: chain.icon,
            actions: actions
        )

        wireframe.presentChainAddressDetails(from: view, model: model)
    }

    // MARK: - Bottom sheet display for secrets type

    private func displaySecretsChangeActions(with title: String, for chain: ChainModel) {
        let createAccountAction = createAccountCreateAction(for: chain)
        let importAccountAction = createAccountImportAction(for: chain)

        let actions: [ChainAddressDetailsModel] = [createAccountAction, importAccountAction]

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

    private func displaySecretsReplaceActions(for chain: ChainModel) {
        let title = R.string.localizable.accountActionsChangeSheetTitle(
            chain.name,
            preferredLanguages: selectedLocale.rLanguages
        )

        displaySecretsChangeActions(with: title, for: chain)
    }

    private func displaySecretsNoAddressActions(for chain: ChainModel) {
        let title = R.string.localizable.accountNotFoundActionsTitle(
            chain.name,
            preferredLanguages: selectedLocale.rLanguages
        )

        displaySecretsChangeActions(with: title, for: chain)
    }

    private func displaySecretsExistingAddressActions(
        for chain: ChainModel,
        viewModel: ChainAccountViewModelItem
    ) {
        guard let view = view, let address = viewModel.address else { return }

        var actions: [ChainAddressDetailsAction] = []

        let copyAction = createCopyAction(for: address)
        actions.append(copyAction)

        let explorerActions = createExplorerActions(for: chain, address: address)

        actions.append(contentsOf: explorerActions)

        let changeAccountAction = createAccountChangeAction(for: chain, walletType: .secrets)
        actions.append(changeAccountAction)

        if let wallet = wallet {
            let exportAccountTitle = LocalizableResource { locale in
                R.string.localizable.commonExport(
                    preferredLanguages: locale.rLanguages
                )
            }

            let exportAction = ChainAddressDetailsAction(
                title: exportAccountTitle,
                icon: nil,
                indicator: .navigation
            ) { [weak self] in
                self?.interactor.requestExportOptions(metaAccount: wallet, chain: chain)
            }

            actions.append(exportAction)
        }

        let model = ChainAddressDetailsModel(
            address: address,
            chainName: chain.name,
            chainIcon: chain.icon,
            actions: actions
        )

        wireframe.presentChainAddressDetails(from: view, model: model)
    }

    // MARK: - Actions

    private func activateCopyAddress(_ address: String) {
        UIPasteboard.general.string = address

        let locale = localizationManager?.selectedLocale
        let title = R.string.localizable.commonCopied(preferredLanguages: locale?.rLanguages)
        wireframe.presentSuccessNotification(title, from: view)
    }

    private func activateChangeAccount(for chainModel: ChainModel, walletType: MetaAccountModelType) {
        switch walletType {
        case .secrets:
            displaySecretsReplaceActions(for: chainModel)
        case .watchOnly:
            if let wallet = wallet {
                wireframe.showChangeWatchOnlyAccount(from: view, wallet: wallet, chain: chainModel)
            }
        }
    }

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

    // MARK: - Bottom sheet items creation

    private func createExplorerActions(for chain: ChainModel, address: AccountAddress) -> [ChainAddressDetailsAction] {
        chain.explorers?.compactMap { explorer in
            guard
                let urlTemplate = explorer.account,
                let url = try? RobinHood.EndpointBuilder(urlTemplate: urlTemplate)
                .buildParameterURL(address) else {
                return nil
            }

            return ChainAddressDetailsAction(
                title: LocalizableResource { _ in explorer.name },
                icon: nil,
                indicator: .navigation
            ) { [weak self] in
                if let view = self?.view {
                    self?.wireframe.showWeb(url: url, from: view, style: .automatic)
                }
            }
        } ?? []
    }

    private func createCopyAction(for address: String) -> ChainAddressDetailsAction {
        let copyTitle = LocalizableResource { locale in
            R.string.localizable.commonCopyAddress(preferredLanguages: locale.rLanguages)
        }

        return ChainAddressDetailsAction(
            title: copyTitle,
            icon: nil,
            indicator: .none
        ) { [weak self] in
            self?.activateCopyAddress(address)
        }
    }

    private func createAccountChangeAction(
        for chain: ChainModel,
        walletType: MetaAccountModelType
    ) -> ChainAddressDetailsAction {
        let createAccountTitle = LocalizableResource { locale in
            R.string.localizable.accountActionsChangeTitle(preferredLanguages: locale.rLanguages)
        }

        return ChainAddressDetailsAction(
            title: createAccountTitle,
            icon: nil,
            indicator: .navigation
        ) { [weak self] in
            self?.activateChangeAccount(for: chain, walletType: walletType)
        }
    }

    private func createAccountAddAction(
        for chain: ChainModel,
        walletType: MetaAccountModelType
    ) -> ChainAddressDetailsAction {
        let addAccountTitle = LocalizableResource { locale in
            R.string.localizable.accountsAddAccount(preferredLanguages: locale.rLanguages)
        }

        return ChainAddressDetailsAction(
            title: addAccountTitle,
            icon: nil,
            indicator: .navigation
        ) { [weak self] in
            self?.activateChangeAccount(for: chain, walletType: walletType)
        }
    }

    private func createAccountCreateAction(for chain: ChainModel) -> ChainAddressDetailsAction {
        let createAccountTitle = LocalizableResource { locale in
            R.string.localizable.accountCreateOptionTitle(preferredLanguages: locale.rLanguages)
        }

        return ChainAddressDetailsAction(
            title: createAccountTitle,
            icon: nil,
            indicator: .navigation
        ) { [weak self] in
            self?.activateCreateAccount(for: chain)
        }
    }

    private func createAccountImportAction(for chain: ChainModel) -> ChainAddressDetailsAction {
        let importAccountTitle = LocalizableResource { locale in
            R.string.localizable.accountImportOptionTitle(preferredLanguages: locale.rLanguages)
        }

        return ChainAddressDetailsAction(
            title: importAccountTitle,
            icon: nil,
            indicator: .navigation
        ) { [weak self] in
            self?.activateImportAccount(for: chain)
        }
    }
}

// MARK: - AccountManagementPresenterProtocol

extension AccountManagementPresenter: AccountManagementPresenterProtocol {
    func setup() {
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
        let chainViewModel = viewModel[indexPath.section]
            .chainAccounts[indexPath.row]

        guard
            let wallet = wallet,
            let chainModel = chains[chainViewModel.chainId] else { return }

        switch wallet.type {
        case .secrets:
            if chainViewModel.address == nil {
                displaySecretsNoAddressActions(for: chainModel)
            } else {
                displaySecretsExistingAddressActions(for: chainModel, viewModel: chainViewModel)
            }
        case .watchOnly:
            if chainViewModel.address == nil {
                displayWatchOnlyNoAddressActions(for: chainModel)
            } else {
                displayWatchOnlyExistingAddressActions(for: chainModel, viewModel: chainViewModel)
            }
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

            updateWalletType()
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

    func didReceive(
        exportOptionsResult: Result<[SecretSource], Error>,
        metaAccount: MetaAccountModel,
        chain: ChainModel
    ) {
        switch exportOptionsResult {
        case let .success(options):
            wireframe.showExportAccount(
                for: metaAccount,
                chain: chain,
                options: options,
                from: view
            )
        case let .failure(error):
            if !wireframe.present(error: error, from: view, locale: selectedLocale) {
                logger?.error("Did receive export error \(error)")
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
