import Foundation
import SoraFoundation
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

    private func getProxiedUpdates(
        for changes: [DataProviderChange<ManagedMetaAccountModel>]
    ) -> [ManagedMetaAccountModel] {
        let oldWallets = walletsList.allItems.reduceToDict()

        return changes.compactMap { change in
            switch change {
            case let .insert(newWallet):
                guard let proxy = newWallet.info.proxy() else {
                    return nil
                }

                return newWallet.info.type == .proxied && proxy.isNotActive ? newWallet : nil
            case let .update(newWallet):
                guard newWallet.info.type == .proxied, let newProxy = newWallet.info.proxy() else {
                    return nil
                }

                let oldProxy = oldWallets[newWallet.identifier]?.info.proxy()

                return newProxy.isNotActive && oldProxy?.status != newProxy.status ? newWallet : nil
            case .delete:
                return nil
            }
        }
    }

    override func updateWallets(changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        let proxiedUpdates = getProxiedUpdates(for: changes)

        super.updateWallets(changes: changes)

        guard let view = baseView, view.controller.topModalViewController == view.controller else {
            return
        }

        if !proxiedUpdates.isEmpty {
            wireframe?.showProxiedsUpdates(from: baseView, initWallets: proxiedUpdates)
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
