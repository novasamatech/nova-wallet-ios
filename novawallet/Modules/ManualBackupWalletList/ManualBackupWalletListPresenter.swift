import Foundation
import SoraFoundation
import RobinHood

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
        
        return super.filterIgnoredWallet(changes: changes)
    }
}

extension ManualBackupWalletListPresenter: ManualBackupWalletListPresenterProtocol {
    func selectItem(at index: Int, section: Int) {
        print("row \(index), section \(section)")
    }
}
