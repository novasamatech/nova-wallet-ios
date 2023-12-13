import Foundation
import RobinHood
import SoraFoundation

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

    private func updateView() {
        let delegatedViewModels = viewModels([.new], wallets: walletsList.allItems)
        let revokedViewModels = viewModels([.revoked], wallets: walletsList.allItems)

        view?.didReceive(delegatedModels: delegatedViewModels, revokedModels: revokedViewModels)
    }

    private func viewModels(_ statuses: [ProxyAccountModel.Status], wallets: [ManagedMetaAccountModel]) -> [WalletView.ViewModel] {
        viewModelsFactory.createViewModels(
            for: wallets,
            statuses: statuses,
            chainModelProvider: { [weak self] in self?.chains[$0] },
            locale: selectedLocale
        )
    }

    func preferredContentHeight() -> CGFloat {
        let delegatedViewModels = viewModels([.new], wallets: initWallets)
        let revokedViewModels = viewModels([.revoked], wallets: initWallets)

        return view?.preferredContentHeight(delegatedModels: delegatedViewModels, revokedModels: revokedViewModels) ?? 0
    }
}

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
        let wikiUrl = applicationConfig.wikiURL
        wireframe.showWeb(url: wikiUrl, from: view, style: .automatic)
    }
}

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

extension DelegatedAccountsUpdatePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
