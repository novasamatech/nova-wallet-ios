import Foundation
import SoraFoundation
import BigInt

final class AssetSelectionPresenter: AssetSelectionBasePresenter {
    var wireframe: AssetSelectionWireframeProtocol? {
        baseWireframe as? AssetSelectionWireframeProtocol
    }

    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    let selectedChainAssetId: ChainAssetId?

    init(
        interactor: AssetSelectionInteractorInputProtocol,
        wireframe: AssetSelectionWireframeProtocol,
        selectedChainAssetId: ChainAssetId?,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedChainAssetId = selectedChainAssetId
        self.assetIconViewModelFactory = assetIconViewModelFactory

        super.init(
            interactor: interactor,
            baseWireframe: wireframe,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            localizationManager: localizationManager
        )
    }

    override func updateView() {
        guard let assets = assets, isReadyForDisplay else {
            return
        }

        let viewModels: [SelectableIconDetailsListViewModel] = assets.compactMap { chainAsset in
            let chain = chainAsset.chain
            let asset = chainAsset.asset

            let icon = assetIconViewModelFactory.createAssetIconViewModel(
                for: asset.icon,
                defaultURL: chain.icon
            )
            let title = asset.name ?? chain.name
            let isSelected = selectedChainAssetId?.assetId == asset.assetId &&
                selectedChainAssetId?.chainId == chain.chainId
            let balance = extractFormattedBalance(for: chainAsset) ?? ""

            return SelectableIconDetailsListViewModel(
                title: title,
                subtitle: balance,
                icon: icon,
                isSelected: isSelected
            )
        }

        updateViewModels(viewModels)

        view?.didReload()
    }

    override func handleAssetSelection(at index: Int) {
        guard let view = view, let assets = assets else {
            return
        }

        wireframe?.complete(on: view, selecting: assets[index])
    }
}
