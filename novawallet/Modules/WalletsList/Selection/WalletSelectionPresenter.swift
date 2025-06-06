import Foundation
import Foundation_iOS
import Operation_iOS

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

    private func getDelegatedAccountsUpdates(
        for changes: [DataProviderChange<ManagedMetaAccountModel>]
    ) -> [ManagedMetaAccountModel] {
        let oldWallets = walletsList.allItems.reduceToDict()

        return changes.compactMap { change in
            switch change {
            case let .insert(newWallet):
                guard let delegationStatus = newWallet.info.delegatedAccountStatus() else {
                    return nil
                }

                return delegationStatus != .active ? newWallet : nil
            case let .update(newWallet):
                guard
                    let oldStatus = oldWallets[newWallet.identifier]?.info.delegatedAccountStatus(),
                    let newStatus = newWallet.info.delegatedAccountStatus()
                else {
                    return nil
                }

                return newStatus != .active && oldStatus != newStatus ? newWallet : nil
            case .delete:
                return nil
            }
        }
    }

    override func updateWallets(changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        let delegatedAccountsUpdates = getDelegatedAccountsUpdates(for: changes)

        super.updateWallets(changes: changes)

        guard let view = baseView, view.controller.topModalViewController == view.controller else {
            return
        }

        if !delegatedAccountsUpdates.isEmpty {
            wireframe?.showDelegatesUpdates(from: baseView, initWallets: delegatedAccountsUpdates)
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

    func viewDidDisappear() {
        interactor?.updateWalletsStatuses()
    }
}

extension WalletSelectionPresenter: WalletSelectionInteractorOutputProtocol {
    func didCompleteSelection() {
        wireframe?.close(view: baseView)
    }
}
