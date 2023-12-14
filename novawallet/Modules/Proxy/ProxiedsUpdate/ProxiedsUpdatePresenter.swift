import Foundation
import RobinHood
import SoraFoundation

final class ProxiedsUpdatePresenter {
    weak var view: ProxiedsUpdateViewProtocol?
    let wireframe: ProxiedsUpdateWireframeProtocol
    let interactor: ProxiedsUpdateInteractorInputProtocol
    let viewModelsFactory: ProxiedsUpdateFactoryProtocol
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
        interactor: ProxiedsUpdateInteractorInputProtocol,
        wireframe: ProxiedsUpdateWireframeProtocol,
        viewModelsFactory: ProxiedsUpdateFactoryProtocol,
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

    private func viewModels(
        _ statuses: [ProxyAccountModel.Status],
        wallets: [ManagedMetaAccountModel]
    ) -> [ProxyWalletView.ViewModel] {
        viewModelsFactory.createViewModels(
            for: wallets,
            statuses: statuses,
            chains: chains,
            locale: selectedLocale
        )
    }

    func preferredContentHeight() -> CGFloat {
        let proxies = initWallets.compactMap {
            $0.info.chainAccounts.first(where: { $0.proxy != nil })
        }
        let newModelsCount = proxies.filter { $0.proxy?.status == .new }.count
        let revokedModelsCount = proxies.filter { $0.proxy?.status == .revoked }.count

        return view?.preferredContentHeight(
            delegatedModelsCount: newModelsCount,
            revokedModelsCount: revokedModelsCount
        ) ?? 0
    }
}

extension ProxiedsUpdatePresenter: ProxiedsUpdatePresenterProtocol {
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

extension ProxiedsUpdatePresenter: ProxiedsUpdateInteractorOutputProtocol {
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

    func didReceiveError(_ error: ProxiedsUpdateError) {
        logger.error(error.localizedDescription)
    }
}

extension ProxiedsUpdatePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
