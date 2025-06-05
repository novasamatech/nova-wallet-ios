import Foundation
import Operation_iOS
import Foundation_iOS

final class DelegatedAccountsUpdatePresenter {
    weak var view: DelegatedAccountsUpdateViewProtocol?
    let wireframe: DelegatedAccountsUpdateWireframeProtocol
    let interactor: DelegatedAccountsUpdateInteractorInputProtocol
    let viewModelsFactory: DelegatedAccountsUpdateFactoryProtocol
    let logger: LoggerProtocol
    let applicationConfig: ApplicationConfigProtocol

    private var chains: [ChainModel.Id: ChainModel] = [:]
    private let initWallets: [ManagedMetaAccountModel]
    private lazy var walletsList = ListDifferenceCalculator<ManagedMetaAccountModel>(
        initialItems: []
    ) { item1, item2 in
        item1.order < item2.order
    }

    private var currentMode: DelegatedAccountsUpdateMode = .proxied

    init(
        interactor: DelegatedAccountsUpdateInteractorInputProtocol,
        wireframe: DelegatedAccountsUpdateWireframeProtocol,
        viewModelsFactory: DelegatedAccountsUpdateFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        applicationConfig: ApplicationConfigProtocol,
        initWallets: [ManagedMetaAccountModel],
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelsFactory = viewModelsFactory
        self.logger = logger
        self.applicationConfig = applicationConfig
        self.initWallets = initWallets
        self.localizationManager = localizationManager
    }

    func preferredContentHeight() -> CGFloat {
        let proxieds = initWallets.compactMap(\.info.proxy)
        let multisigs = initWallets.compactMap(\.info.multisig)

        let delegatedAccounts: [any DelegatedAccountProtocol] = proxieds.count > multisigs.count
            ? proxieds
            : multisigs

        let newModelsCount = delegatedAccounts.filter { $0.status == .new }.count
        let revokedModelsCount = delegatedAccounts.filter { $0.status == .revoked }.count

        let hasProxied = !proxieds.isEmpty
        let hasMultisig = !multisigs.isEmpty
        let shouldShowSegmentedControl = hasProxied && hasMultisig

        return view?.preferredContentHeight(
            delegatedModelsCount: newModelsCount,
            revokedModelsCount: revokedModelsCount,
            shouldShowSegmentedControl: shouldShowSegmentedControl
        ) ?? 0
    }
}

// MARK: - Private

private extension DelegatedAccountsUpdatePresenter {
    func updateView() {
        let delegatedViewModels = viewModels([.new], wallets: walletsList.allItems)
        let revokedViewModels = viewModels([.revoked], wallets: walletsList.allItems)

        let hasProxied = !initWallets.filter { $0.info.type == .proxied }.isEmpty
        let hasMultisig = !initWallets.filter { $0.info.type == .multisig }.isEmpty
        let shouldShowSegmentedControl = hasProxied && hasMultisig

        if !shouldShowSegmentedControl {
            if hasProxied {
                currentMode = .proxied
            } else if hasMultisig {
                currentMode = .multisig
            }
            view?.switchMode(currentMode)
        }

        view?.didReceive(
            delegatedModels: delegatedViewModels,
            revokedModels: revokedViewModels,
            shouldShowSegmentedControl: shouldShowSegmentedControl
        )
    }

    func viewModels(
        _ statuses: [DelegatedAccount.Status],
        wallets: [ManagedMetaAccountModel]
    ) -> [WalletView.ViewModel] {
        if currentMode == .proxied {
            viewModelsFactory.createProxiedViewModels(
                for: wallets,
                statuses: statuses,
                chains: chains,
                locale: selectedLocale
            )
        } else {
            viewModelsFactory.createMultisigViewModels(
                for: wallets,
                statuses: statuses,
                chains: chains,
                locale: selectedLocale
            )
        }
    }
}

// MARK: - DelegatedAccountsUpdatePresenterProtocol

extension DelegatedAccountsUpdatePresenter: DelegatedAccountsUpdatePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func done() {
        wireframe.close(from: view)
    }

    func showInfo() {
        guard let view = view else {
            return
        }

        let url = currentMode == .proxied ?
            applicationConfig.proxyWikiURL :
            applicationConfig.proxyWikiURL

        wireframe.close(from: view, andPresent: url)
    }

    func didSelectMode(_ mode: DelegatedAccountsUpdateMode) {
        currentMode = mode
        updateView()
    }
}

// MARK: - DelegatedAccountsUpdateInteractorOutputProtocol

extension DelegatedAccountsUpdatePresenter: DelegatedAccountsUpdateInteractorOutputProtocol {
    func didReceiveWalletsChanges(_ changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        walletsList.apply(changes: changes)
        updateView()
    }

    func didReceiveChainChanges(_ changes: [DataProviderChange<ChainModel>]) {
        chains = changes.reduce(into: chains) { result, change in
            switch change {
            case let .insert(newItem):
                result[newItem.chainId] = newItem
            case let .update(newItem):
                result[newItem.chainId] = newItem
            case let .delete(deletedIdentifier):
                result[deletedIdentifier] = nil
            }
        }
        updateView()
    }

    func didReceiveError(_ error: DelegatedAccountsUpdateError) {
        logger.error(error.localizedDescription)
    }
}

// MARK: - Localizable

extension DelegatedAccountsUpdatePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
