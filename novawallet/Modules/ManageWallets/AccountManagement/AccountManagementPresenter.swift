import Foundation
import IrohaCrypto
import Foundation_iOS

final class AccountManagementPresenter {
    enum ChangeAccountOption: Int {
        case createAccount
        case importAccount
    }

    weak var view: AccountManagementViewProtocol?
    var wireframe: AccountManagementWireframeProtocol!
    var interactor: AccountManagementInteractorInputProtocol!

    let viewModelFactory: ChainAccountViewModelFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let walletId: String
    let logger: LoggerProtocol?

    private var wallet: MetaAccountModel?
    private var proxyWallet: MetaAccountModel?

    private var chains: [ChainModel.Id: ChainModel] = [:]
    private var viewModel: ChainAccountListViewModel = []

    private var cloudBackupSyncState: CloudBackupSyncState?

    init(
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        walletId: String,
        applicationConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.viewModelFactory = viewModelFactory
        self.walletId = walletId
        self.applicationConfig = applicationConfig
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

    private func updateProxyWallet() {
        guard let wallet = wallet,
              let proxyWallet = proxyWallet else {
            return
        }
        let proxyViewModel = viewModelFactory.createProxyViewModel(
            proxiedWallet: wallet,
            proxyWallet: proxyWallet,
            locale: selectedLocale
        )
        view?.setProxy(viewModel: proxyViewModel)
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

    private func checkLedgerWarning() {
        guard case .ledger = wallet?.type else {
            return
        }

        if chains.contains(where: { $0.value.supportsGenericLedgerApp }) {
            let viewModel = LedgerMigrationBannerView.ViewModel.createLedgerMigrationDownload(
                for: selectedLocale
            ) { [weak self] in
                self?.showLegacyLedgerFindMore()
            }

            view?.setLedger(migrationViewModel: viewModel)
        }
    }

    private func showLegacyLedgerFindMore() {
        guard let view else {
            return
        }

        wireframe.showWeb(
            url: applicationConfig.ledgerMigrationURL,
            from: view,
            style: .automatic
        )
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

        let copyAction = createCopyAction(for: address, chain: chain)
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

            return ActionManageViewModel(icon: R.image.iconCircleOutline(), title: title, details: nil)
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

        let copyAction = createCopyAction(for: address, chain: chain)
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

    private func displayProxyAddressActions(
        for chain: ChainModel,
        viewModel: ChainAccountViewModelItem
    ) {
        displayExistingHardwareAddressActions(
            for: chain,
            viewModel: viewModel
        )
    }

    private func displayExistingHardwareAddressActions(
        for chain: ChainModel,
        viewModel: ChainAccountViewModelItem
    ) {
        guard let view = view, let address = viewModel.address else {
            return
        }

        var actions: [ChainAddressDetailsAction] = []

        let copyAction = createCopyAction(for: address, chain: chain)
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

    private func presentCloudRemindIfNeededBefore(closure: @escaping () -> Void) {
        if let cloudBackupSyncState, cloudBackupSyncState.canAutoSync {
            wireframe.showCloudBackupRemind(from: view) {
                closure()
            }
        } else {
            closure()
        }
    }

    // MARK: - Actions

    private func activateCopyAddress(
        _ address: String,
        chain: ChainModel
    ) {
        wireframe.copyAddressCheckingFormat(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }

    private func activateChangeAccount(for chainModel: ChainModel, walletType: MetaAccountModelType) {
        switch walletType {
        case .secrets:
            displaySecretsReplaceActions(for: chainModel)
        case .watchOnly, .proxied:
            if let wallet = wallet {
                presentCloudRemindIfNeededBefore { [weak self] in
                    self?.wireframe.showChangeWatchOnlyAccount(
                        from: self?.view,
                        wallet: wallet,
                        chain: chainModel
                    )
                }
            }
        case .paritySigner, .polkadotVault, .ledger, .genericLedger:
            // change account not supported for Parity Signer and Ledger Wallets
            break
        }
    }

    private func activateCreateAccount(for chainModel: ChainModel) {
        guard let view = view,
              let wallet = wallet
        else { return }

        if let cloudBackupSyncState, cloudBackupSyncState.canAutoSync {
            wireframe.showCloudBackupRemind(from: view) { [weak self] in
                self?.interactor.createAccount(for: wallet.metaId, chain: chainModel)
            }
        } else {
            wireframe.showCreateAccount(
                from: view,
                wallet: wallet,
                chainId: chainModel.chainId,
                isEthereumBased: chainModel.isEthereumBased
            )
        }
    }

    private func activateImportAccount(for chainModel: ChainModel) {
        guard let view = view,
              let wallet = wallet
        else { return }

        presentCloudRemindIfNeededBefore { [weak self] in
            self?.wireframe.showImportAccount(
                from: view,
                wallet: wallet,
                chainId: chainModel.chainId,
                isEthereumBased: chainModel.isEthereumBased
            )
        }
    }

    // MARK: - Bottom sheet items creation

    private func createExplorerActions(for chain: ChainModel, address: AccountAddress) -> [ChainAddressDetailsAction] {
        chain.explorers?.compactMap { explorer in
            guard
                let urlTemplate = explorer.account,
                let url = try? URLBuilder(urlTemplate: urlTemplate)
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

    private func createCopyAction(
        for address: String,
        chain: ChainModel
    ) -> ChainAddressDetailsAction {
        let copyTitle = LocalizableResource { locale in
            R.string.localizable.commonCopyAddress(preferredLanguages: locale.rLanguages)
        }

        return ChainAddressDetailsAction(
            title: copyTitle,
            icon: R.image.iconActionCopy(),
            indicator: .none
        ) { [weak self] in
            self?.activateCopyAddress(address, chain: chain)
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
        case .secrets, .watchOnly, .paritySigner, .polkadotVault, .proxied:
            handlingClosure = { [weak self] in
                self?.activateChangeAccount(for: chain, walletType: walletType)
            }
        case .ledger, .genericLedger:
            handlingClosure = { [weak self] in
                guard let wallet = self?.wallet else {
                    return
                }

                self?.presentCloudRemindIfNeededBefore {
                    self?.wireframe.showAddLedgerAccount(
                        from: self?.view,
                        wallet: wallet,
                        chain: chain
                    )
                }
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
        case .proxied:
            displayProxyAddressActions(for: chainModel, viewModel: chainViewModel)
        case .paritySigner, .polkadotVault:
            if chainViewModel.address != nil {
                displayExistingHardwareAddressActions(for: chainModel, viewModel: chainViewModel)
            }
        case .ledger:
            if chainViewModel.address != nil {
                displayExistingHardwareAddressActions(for: chainModel, viewModel: chainViewModel)
            } else {
                displayAddAddress(for: chainModel, walletType: .ledger)
            }
        case .genericLedger:
            displayExistingHardwareAddressActions(for: chainModel, viewModel: chainViewModel)
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
            checkLedgerWarning()

        case let .failure(error):
            logger?.error("Did receive wallet fetch error: \(error)")
        }
    }

    func didReceiveProxyWallet(_ result: Result<MetaAccountModel?, Error>) {
        switch result {
        case let .success(proxyWallet):
            guard let proxyWallet = proxyWallet else {
                logger?.error("Didn't find proxy wallet for proxied wallet with id: \(walletId)")
                return
            }
            self.proxyWallet = proxyWallet
            updateProxyWallet()
        case let .failure(error):
            logger?.error("Did receive proxy wallet fetch error: \(error)")
        }
    }

    func didReceiveChains(_ result: Result<[ChainModel.Id: ChainModel], Error>) {
        switch result {
        case let .success(chains):
            self.chains = chains
            updateChainViewModels()
            checkLedgerWarning()

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

    func didReceiveCloudBackup(state: CloudBackupSyncState) {
        cloudBackupSyncState = state
    }

    func didReceiveAccountCreationResult(_ result: Result<Void, Error>, chain _: ChainModel) {
        switch result {
        case .success:
            break
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
