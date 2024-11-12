import Foundation
import UIKit

// MARK: AssetsSearchCollectionManager

protocol AssetsSearchCollectionManagerProtocol {
    func setupCollectionView()
    func updateGroupsViewModel(with model: AssetListViewModel)
    func updateSelectedLocale(with locale: Locale)

    func updateTokensGroupLayout()
}

protocol AssetsSearchCollectionManagerDelegate: AnyObject {
    func selectAsset(for chainAssetId: ChainAssetId)
    func selectGroup(with symbol: AssetModel.Symbol)
}

protocol AssetsSearchCollectionSelectionDelegate: AnyObject {
    func selectAsset(for chainAssetId: ChainAssetId)
    func selectGroup(
        with symbol: AssetModel.Symbol,
        at indexPath: IndexPath
    )
}

protocol AssetsSearchCollectionViewLayoutDelegate: AnyObject {
    func groupExpanded(for symbol: String) -> Bool
    func groupExpandable(for symbol: String) -> Bool
    func expandAssetGroup(for symbol: String)
    func collapseAssetGroup(for symbol: String)
    func sectionInsets(
        for type: AssetsSearchFlowLayout.SectionType,
        section: Int
    ) -> UIEdgeInsets
    func cellHeight(
        for type: AssetsSearchFlowLayout.CellType,
        at indexPath: IndexPath
    ) -> CGFloat
}

protocol AssetsSearchViewProtocol: ControllerBackedProtocol {
    func didReceiveList(viewModel: AssetListViewModel)
    func didReceiveAssetGroupsStyle(_ style: AssetListGroupsStyle)
}

protocol AssetsSearchPresenterProtocol: AnyObject {
    func setup()
    func selectAsset(for chainAssetId: ChainAssetId)
    func selectGroup(with symbol: AssetModel.Symbol)
    func updateSearch(query: String)
    func cancel()
}

protocol AssetsSearchInteractorInputProtocol: AnyObject {
    func setup()
    func search(query: String)
}

protocol AssetsSearchInteractorOutputProtocol: AnyObject {
    func didReceive(result: AssetSearchBuilderResult)
    func didReceiveAssetGroupsStyle(_ style: AssetListGroupsStyle)
}

protocol AssetsSearchWireframeProtocol: AnyObject {
    func close(view: ControllerBackedProtocol?, completion: (() -> Void)?)
}

extension AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?) {
        close(view: view, completion: nil)
    }
}

protocol AssetsSearchDelegate: AnyObject {
    func assetSearchDidSelect(chainAssetId: ChainAssetId)
    func assetSearchDidCancel()
}

extension AssetsSearchDelegate {
    func assetSearchDidCancel() {}
}
