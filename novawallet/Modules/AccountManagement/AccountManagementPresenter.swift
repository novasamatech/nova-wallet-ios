import Foundation
import RobinHood
import IrohaCrypto
import SoraFoundation

final class AccountManagementPresenter {
    enum ChangeAccountOption: Int {
        case createAccount
        case importAccount
    }

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

    // MARK: Common bottom sheet

    private func displayAddAddress(for chain: ChainModel, walletType: MetaAccountModelType) {
        guard let view = view else {
            return
        }

        let addAction = createAccountAddAction(for: chain, walletType: walletType)

        let actions: [ChainAddressDetailsAction] = [addAction]

        let model = ChainAddressDetailsModel(
            address: nil,
            chainName: chain.name,
            chainIcon: chain.icon,
            actions: actions
        )

        wireframe.presentChainAddressDetails(from: view, model: model)
    }

    // MARK: - Bottom sheet display for watch only type

    private func displayWatchOnlyNoAddressActions(for chain: ChainModel) {
        displayAddAddress(for: chain, walletType: .watchOnly)
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

    private func displaySecretsChangeActions(with title: LocalizableResource<String>, chain: ChainModel) {
        guard let view = view else {
            return
        }

        let createAction: LocalizableResource<ActionManageViewModel> = LocalizableResource { locale in
            let title = R.string.localizable.accountCreateOptionTitle(preferredLanguages: locale.rLanguages)

            return ActionManageViewModel(icon: R.image.iconPlusFilled(), title: title, details: nil)
        }

        let importAction: LocalizableResource<ActionManageViewModel> = LocalizableResource { locale in
            let title = R.string.localizable.accountImportOptionTitle(preferredLanguages: locale.rLanguages)

            return ActionManageViewModel(icon: R.image.iconImportWallet(), title: title, details: nil)
        }

        let context = ModalPickerClosureContext { [weak self] index in
            switch ChangeAccountOption(rawValue: index) {
            case .createAccount:
                self?.activateCreateAccount(for: chain)
            case .importAccount:
                self?.activateImportAccount(for: chain)
            case .none:
                break
            }
        }

        wireframe.presentActionsManage(
            from: view,
            actions: [createAction, importAction],
            title: title,
            delegate: self,
            context: context
        )
    }

    private func displaySecretsReplaceActions(for chain: ChainModel) {
        let title = LocalizableResource { locale in
            R.string.localizable.accountActionsChangeSheetTitle(
                chain.name,
                preferredLanguages: locale.rLanguages
            )
        }

        displaySecretsChangeActions(with: title, chain: chain)
    }

    private func displaySecretsNoAddressActions(for chain: ChainModel) {
        let title = LocalizableResource { locale in
            R.string.localizable.accountNotFoundActionsTitle(
                chain.name,
                preferredLanguages: locale.rLanguages
            )
        }

        displaySecretsChangeActions(with: title, chain: chain)
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
                icon: R.image.iconActionExport(),
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

    private func displayExistingHardwareAddressActions(
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
        case .paritySigner, .ledger:
            // change account not supported for Parity Signer and Ledger Wallets
            break
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

            let title = LocalizableResource { locale in
                R.string.localizable.commmonViewInFormat(
                    explorer.name,
                    preferredLanguages: locale.rLanguages
                )
            }

            return ChainAddressDetailsAction(
                title: title,
                icon: R.image.iconActionWeb(),
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
            icon: R.image.iconActionCopy(),
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
            icon: R.image.iconActionChange(),
            indicator: .navigation
        ) { [weak self] in
            self?.activateChangeAccount(for: chain, walletType: walletType)
        }
    }

    private func createAccountAddAction(
        for chain: ChainModel,
        walletType: MetaAccountModelType
    ) -> ChainAddressDetailsAction {
        let handlingClosure: () -> Void

        switch walletType {
        case .secrets, .watchOnly, .paritySigner:
            handlingClosure = { [weak self] in
                self?.activateChangeAccount(for: chain, walletType: walletType)
            }
        case .ledger:
            handlingClosure = { [weak self] in
                guard let wallet = self?.wallet else {
                    return
                }

                self?.wireframe.showAddLedgerAccount(
                    from: self?.view,
                    wallet: wallet,
                    chain: chain
                )
            }
        }

        let addAccountTitle = LocalizableResource { locale in
            R.string.localizable.accountsAddAccount(preferredLanguages: locale.rLanguages)
        }

        return ChainAddressDetailsAction(
            title: addAccountTitle,
            icon: R.image.iconActionChange(),
            indicator: .navigation,
            onSelection: handlingClosure
        )
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

    func titleForSection(_ section: Int) -> LocalizableResource<String>? {
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
        case .paritySigner:
            if chainViewModel.address != nil {
                displayExistingHardwareAddressActions(for: chainModel, viewModel: chainViewModel)
            }
        case .ledger:
            if chainViewModel.address != nil {
                displayExistingHardwareAddressActions(for: chainModel, viewModel: chainViewModel)
            } else {
                displayAddAddress(for: chainModel, walletType: .ledger)
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

extension AccountManagementPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let context = context as? ModalPickerClosureContext else {
            return
        }

        context.process(selectedIndex: index)
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
