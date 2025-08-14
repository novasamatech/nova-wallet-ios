import Foundation
import NovaCrypto
import Foundation_iOS

final class AccountManagementPresenter {
    enum ChangeAccountOption: Int {
        case createAccount
        case importAccount
    }

    weak var view: AccountManagementViewProtocol?
    var wireframe: AccountManagementWireframeProtocol!
    var interactor: AccountManagementInteractorInputProtocol!

    let viewModelFactory: AccountManagementViewModelFactoryProtocol
    let chainAccountViewModelFactory: ChainAccountViewModelFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let walletId: String
    let logger: LoggerProtocol?

    private var wallet: MetaAccountModel?
    private var delegateWallet: MetaAccountModel?

    private var chains: [ChainModel.Id: ChainModel] = [:]
    private var viewModel: ChainAccountListViewModel = []

    private var cloudBackupSyncState: CloudBackupSyncState?

    init(
        viewModelFactory: AccountManagementViewModelFactoryProtocol,
        chainAccountViewModelFactory: ChainAccountViewModelFactoryProtocol,
        walletId: String,
        applicationConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.viewModelFactory = viewModelFactory
        self.chainAccountViewModelFactory = chainAccountViewModelFactory
        self.walletId = walletId
        self.applicationConfig = applicationConfig
        self.logger = logger
    }
}

// MARK: - Private

private extension AccountManagementPresenter {
    // MARK: - Updating functions

    func provideWalletViewModel() {
        guard let wallet else { return }

        let params = AccountManagementViewModelParams(
            wallet: wallet,
            delegateWallet: delegateWallet,
            chains: chains,
            signatoryInfoAction: { [weak self] address in
                self?.showSignatoryInfo(address: address)
            },
            legacyLedgerAction: { [weak self] in
                self?.showLegacyLedgerFindMore()
            },
            locale: selectedLocale
        )

        let viewModel = viewModelFactory.createViewModel(params: params)

        view?.didReceive(walletViewModel: viewModel)
    }

    func provideChainViewModels() {
        guard let wallet else { return }

        viewModel = chainAccountViewModelFactory.createViewModel(
            from: wallet,
            chains: chains,
            for: selectedLocale
        )

        view?.reload()
    }

    func provideNameViewModel() {
        guard let wallet else { return }

        let processor = ByteLengthProcessor.username
        let processedUsername = processor.process(text: wallet.name)

        let inputHandling = InputHandler(
            value: processedUsername,
            predicate: NSPredicate.notEmpty,
            processor: processor
        )

        let nameViewModel = InputViewModel(inputHandler: inputHandling)
        nameViewModel.inputHandler.addObserver(self)

        view?.didReceive(nameViewModel: nameViewModel)
    }

    func showLegacyLedgerFindMore() {
        guard let view else {
            return
        }

        wireframe.showWeb(
            url: applicationConfig.ledgerMigrationURL,
            from: view,
            style: .automatic
        )
    }

    func showSignatoryInfo(address: String) {
        guard
            let view,
            let multisigAccount = wallet?.multisigAccount
        else { return }

        switch multisigAccount {
        case let .singleChain(chainAccount):
            guard let chain = chains[chainAccount.chainId] else { return }

            wireframe.presentAccountOptions(
                from: view,
                address: address,
                chain: chain,
                locale: selectedLocale
            )
        case .universalSubstrate:
            wireframe.presentSubstrateAddressOptions(
                from: view,
                address: address,
                locale: selectedLocale
            )
        case .universalEvm:
            wireframe.presentEvmAddressOptions(
                from: view,
                address: address,
                locale: selectedLocale
            )
        }
    }

    // MARK: Common bottom sheet

    func displayAddAddress(for chain: ChainModel, walletType: MetaAccountModelType) {
        guard let view else {
            return
        }

        let addAction = createAccountAddAction(for: chain, walletType: walletType)

        let actions: [ChainAddressDetailsAction] = [addAction]

        let model = ChainAddressDetailsModel(
            address: nil,
            title: .init(chain: chain),
            actions: actions
        )

        wireframe.presentChainAddressDetails(from: view, model: model)
    }

    // MARK: - Bottom sheet display for watch only type

    func displayWatchOnlyNoAddressActions(for chain: ChainModel) {
        displayAddAddress(for: chain, walletType: .watchOnly)
    }

    func displayWatchOnlyExistingAddressActions(
        for chain: ChainModel,
        viewModel: ChainAccountViewModelItem
    ) {
        guard let view, let address = viewModel.address else {
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
            title: .init(chain: chain),
            actions: actions
        )

        wireframe.presentChainAddressDetails(from: view, model: model)
    }

    // MARK: - Bottom sheet display for secrets type

    func displaySecretsChangeActions(with title: LocalizableResource<String>, chain: ChainModel) {
        guard let view else {
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

    func displaySecretsReplaceActions(for chain: ChainModel) {
        let title = LocalizableResource { locale in
            R.string.localizable.accountActionsChangeSheetTitle(
                chain.name,
                preferredLanguages: locale.rLanguages
            )
        }

        displaySecretsChangeActions(with: title, chain: chain)
    }

    func displaySecretsNoAddressActions(for chain: ChainModel) {
        let title = LocalizableResource { locale in
            R.string.localizable.accountNotFoundActionsTitle(
                chain.name,
                preferredLanguages: locale.rLanguages
            )
        }

        displaySecretsChangeActions(with: title, chain: chain)
    }

    func displaySecretsExistingAddressActions(
        for chain: ChainModel,
        viewModel: ChainAccountViewModelItem
    ) {
        guard let view, let address = viewModel.address else { return }

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
            title: .init(chain: chain),
            actions: actions
        )

        wireframe.presentChainAddressDetails(from: view, model: model)
    }

    func displayDelegateAddressActions(
        for chain: ChainModel,
        viewModel: ChainAccountViewModelItem
    ) {
        displayExistingHardwareAddressActions(
            for: chain,
            viewModel: viewModel
        )
    }

    func displayExistingHardwareAddressActions(
        for chain: ChainModel,
        viewModel: ChainAccountViewModelItem
    ) {
        guard let view, let address = viewModel.address else {
            return
        }

        var actions: [ChainAddressDetailsAction] = []

        let copyAction = createCopyAction(for: address, chain: chain)
        actions.append(copyAction)

        let explorerActions = createExplorerActions(for: chain, address: address)

        actions.append(contentsOf: explorerActions)

        let model = ChainAddressDetailsModel(
            address: address,
            title: .init(chain: chain),
            actions: actions
        )

        wireframe.presentChainAddressDetails(from: view, model: model)
    }

    func presentCloudRemindIfNeededBefore(closure: @escaping () -> Void) {
        if let cloudBackupSyncState, cloudBackupSyncState.canAutoSync {
            wireframe.showCloudBackupRemind(from: view) {
                closure()
            }
        } else {
            closure()
        }
    }

    // MARK: - Actions

    func activateCopyAddress(
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

    func activateChangeAccount(for chainModel: ChainModel, walletType: MetaAccountModelType) {
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
        case .paritySigner, .polkadotVault, .ledger, .genericLedger, .multisig:
            // change account not supported for Parity Signer, Ledger and Multisig wallets
            break
        }
    }

    func activateCreateAccount(for chainModel: ChainModel) {
        guard let view, let wallet else { return }

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

    func activateImportAccount(for chainModel: ChainModel) {
        guard let view, let wallet else { return }

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

    func createExplorerActions(for chain: ChainModel, address: AccountAddress) -> [ChainAddressDetailsAction] {
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

    func createCopyAction(
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

    func createAccountChangeAction(
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

    func createAccountAddAction(
        for chain: ChainModel,
        walletType: MetaAccountModelType
    ) -> ChainAddressDetailsAction {
        let handlingClosure: () -> Void

        switch walletType {
        case .secrets, .watchOnly, .paritySigner, .polkadotVault, .proxied, .multisig:
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

    func actionForSection(_ section: Int) -> LocalizableResource<IconWithTitleViewModel>? {
        viewModel[section].section.action
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
        case .proxied, .multisig:
            displayDelegateAddressActions(for: chainModel, viewModel: chainViewModel)
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

    func activateActionInSection(_: Int) {
        guard let wallet else {
            return
        }

        // generic ledger currently the only case for the sections with action

        switch wallet.type {
        case .genericLedger:
            presentCloudRemindIfNeededBefore { [weak self] in
                guard let self else {
                    return
                }

                wireframe.showAddGenericLedgerEvmAccounts(
                    from: view,
                    wallet: wallet
                )
            }
        case .secrets,
             .watchOnly,
             .paritySigner,
             .ledger,
             .polkadotVault,
             .proxied,
             .multisig:
            break
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
            guard let wallet else {
                logger?.error("Did find no wallets with Id: \(walletId)")
                return
            }

            self.wallet = wallet
            provideNameViewModel()
            provideChainViewModels()
            provideWalletViewModel()
        case let .failure(error):
            logger?.error("Did receive wallet fetch error: \(error)")
        }
    }

    func didReceiveDelegateWallet(_ result: Result<MetaAccountModel?, Error>) {
        switch result {
        case let .success(delegateWallet):
            guard let delegateWallet else {
                logger?.error("Didn't find delegate wallet for delegated wallet with id: \(walletId)")
                return
            }

            self.delegateWallet = delegateWallet
            provideWalletViewModel()
        case let .failure(error):
            logger?.error("Did receive delegate wallet fetch error: \(error)")
        }
    }

    func didReceiveChains(_ result: Result<[ChainModel.Id: ChainModel], Error>) {
        switch result {
        case let .success(chains):
            self.chains = chains
            provideChainViewModels()
            provideWalletViewModel()
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
            provideWalletViewModel()
            provideChainViewModels()
        }
    }
}
