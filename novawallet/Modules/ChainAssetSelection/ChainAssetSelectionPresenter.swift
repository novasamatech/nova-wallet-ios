import Foundation
import Foundation_iOS
import BigInt

final class ChainAssetSelectionPresenter: ChainAssetSelectionBasePresenter {
    var wireframe: ChainAssetSelectionWireframeProtocol? {
        baseWireframe as? ChainAssetSelectionWireframeProtocol
    }

    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    let selectedChainAssetId: ChainAssetId?
    let balanceMapper: AvailableBalanceMapping

    init(
        interactor: ChainAssetSelectionInteractorInputProtocol,
        wireframe: ChainAssetSelectionWireframeProtocol,
        selectedChainAssetId: ChainAssetId?,
        balanceMapper: AvailableBalanceMapping,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedChainAssetId = selectedChainAssetId
        self.balanceMapper = balanceMapper
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

            let icon = ImageViewModelFactory.createChainIconOrDefault(from: chain.icon)
            let title = asset.name ?? chain.name
            let isSelected = selectedChainAssetId?.assetId == asset.assetId &&
                selectedChainAssetId?.chainId == chain.chainId
            let balance = extractFormattedBalance(for: chainAsset, balanceMapper: balanceMapper) ?? ""

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

    override func updateAvailableOptions() {
        assets?.sort { orderAssets($0, chainAsset2: $1, balanceMapper: balanceMapper) }
    }
}
