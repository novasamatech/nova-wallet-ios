import Foundation
import SoraFoundation
import RobinHood

final class WalletSelectionPresenter: WalletsListPresenter {
    var interactor: WalletSelectionInteractorInputProtocol? {
        baseInteractor as? WalletSelectionInteractorInputProtocol
    }

    var wireframe: WalletSelectionWireframeProtocol? {
        baseWireframe as? WalletSelectionWireframeProtocol
    }

    init(
        interactor: WalletSelectionInteractorInputProtocol,
        wireframe: WalletSelectionWireframeProtocol,
        viewModelFactory: WalletsListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        super.init(
            baseInteractor: interactor,
            baseWireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    override func updateWallets(changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        super.updateWallets(changes: changes)

        guard let view = baseView, view.controller.topModalViewController == view.controller else {
            return
        }

        let proxyWalletChanged = walletsList.lastDifferences.contains {
            switch $0 {
            case let .delete(_, metaAccount):
                return metaAccount.info.type == .proxied
            case let .insert(_, metaAccount):
                return metaAccount.info.type == .proxied && metaAccount.info.chainAccounts.contains {
                    $0.proxy?.status == .new || $0.proxy?.status == .revoked
                } ? true : false
            case let .update(_, old, new):
                guard old.info.type == .proxied, new.info.type == .proxied else {
                    return false
                }
                let oldProxy = old.info.chainAccounts.first(where: { $0.proxy?.isNotActive == true })
                let newProxy = new.info.chainAccounts.first(where: { $0.proxy != nil })
                return oldProxy?.proxy?.status != newProxy?.proxy?.status
            }
        }

        if proxyWalletChanged {
            wireframe?.showProxiedsUpdates(
                from: baseView,
                initWallets: walletsList.allItems
            )
        }
    }
}

extension WalletSelectionPresenter: WalletSelectionPresenterProtocol {
    func selectItem(at index: Int, section: Int) {
        let identifier = viewModels[section].items[index].identifier

        guard
            let item = walletsList.allItems.first(where: { $0.identifier == identifier }),
            !item.isSelected else {
            return
        }

        interactor?.select(item: item)
    }

    func activateSettings() {
        wireframe?.showSettings(from: baseView)
    }

    func didReceive(saveError: Error) {
        super.didReceiveError(saveError)
    }

    func viewWillDisappear() {
        interactor?.updateWalletsStatuses()
    }
}

extension WalletSelectionPresenter: WalletSelectionInteractorOutputProtocol {
    func didCompleteSelection() {
        wireframe?.close(view: baseView)
    }
}
