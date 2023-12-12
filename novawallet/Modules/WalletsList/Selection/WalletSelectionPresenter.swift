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

    private var shouldShowDelegatesUpdates: Bool = true

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
        guard shouldShowDelegatesUpdates else {
            return
        }
        let proxyWalletChanged = walletsList.lastDifferences.contains {
            switch $0 {
            case let .delete(_, metaAccount):
                return metaAccount.info.type == .proxy
            case let .insert(_, metaAccount), let .update(_, _, metaAccount):
                return metaAccount.info.type == .proxy && metaAccount.info.chainAccounts.contains {
                    $0.proxy?.status == .new || $0.proxy?.status == .revoked
                } ? true : false
            }
        }

        if proxyWalletChanged {
            shouldShowDelegatesUpdates = false
            wireframe?.showDelegateUpdates(
                from: baseView,
                initWallets: walletsList.allItems
            ) { [weak self] in
                self?.shouldShowDelegatesUpdates = true
            }
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
        interactor?.updateWalletsStatuses()
        wireframe?.showSettings(from: baseView)
    }

    func didUpdateWallets() {}
}

extension WalletSelectionPresenter: WalletSelectionInteractorOutputProtocol {
    func didCompleteSelection() {
        interactor?.updateWalletsStatuses()
        wireframe?.close(view: baseView)
    }
}
