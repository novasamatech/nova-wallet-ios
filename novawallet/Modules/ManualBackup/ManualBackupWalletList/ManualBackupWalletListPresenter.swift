import Foundation
import Foundation_iOS
import Operation_iOS

final class ManualBackupWalletListPresenter: WalletsListPresenter {
    var wireframe: ManualBackupWalletListWireframeProtocol? {
        baseWireframe as? ManualBackupWalletListWireframeProtocol
    }

    init(
        interactor: WalletsListInteractorInputProtocol,
        wireframe: ManualBackupWalletListWireframeProtocol,
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

    override func filterIgnoredWallet(
        changes: [DataProviderChange<ManagedMetaAccountModel>]
    ) -> [DataProviderChange<ManagedMetaAccountModel>] {
        let secrets = changes.filter { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                return newItem.info.type == .secrets
            case .delete:
                return true
            }
        }

        return super.filterIgnoredWallet(changes: secrets)
    }
}

extension ManualBackupWalletListPresenter: ManualBackupWalletListPresenterProtocol {
    func selectItem(at index: Int, section: Int) {
        let identifier = viewModels[section].items[index].identifier

        guard let wallet = walletsList.allItems.first(where: { $0.identifier == identifier }) else {
            return
        }

        if wallet.info.chainAccounts.isEmpty {
            wireframe?.showBackupAttention(
                from: baseView,
                metaAccount: wallet.info
            )
        } else {
            wireframe?.showChainAccountsList(
                from: baseView,
                metaAccount: wallet.info
            )
        }
    }
}
