import Foundation
import RobinHood

protocol WalletsListViewProtocol: ControllerBackedProtocol {
    func didReload()
}

protocol WalletsListPresenterProtocol: AnyObject {
    func setup()

    func numberOfSections() -> Int
    func numberOfItems(in section: Int) -> Int
    func item(at index: Int, in section: Int) -> WalletsListViewModel
    func section(at index: Int) -> WalletsListSectionViewModel
}

protocol WalletsListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol WalletsListInteractorOutputProtocol: AnyObject {
    func didReceiveWalletsChanges(_ changes: [DataProviderChange<ManagedMetaAccountModel>])
    func didReceiveBalancesChanges(_ changes: [DataProviderChange<AssetBalance>])
    func didReceiveChainChanges(_ changes: [DataProviderChange<ChainModel>])
    func didReceivePrices(_ prices: [ChainAssetId: PriceData])
    func didReceiveError(_ error: Error)
}

protocol WalletsListWireframeProtocol: AlertPresentable, ErrorPresentable {}
