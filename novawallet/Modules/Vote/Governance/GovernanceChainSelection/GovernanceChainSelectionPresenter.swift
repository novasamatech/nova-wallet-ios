import Foundation
import SoraFoundation

final class GovernanceChainSelectionPresenter: ChainAssetSelectionBasePresenter {
    var wireframe: GovernanceChainSelectionWireframeProtocol? {
        baseWireframe as? GovernanceChainSelectionWireframeProtocol
    }

    struct Option {
        let chainAsset: ChainAsset
        let governanceType: GovernanceType
    }

    private var availableOptions: [Option] = []

    private var selectedGovernanceType: GovernanceType?
    private var selectedChainId: ChainModel.Id?

    private let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    init(
        interactor: ChainAssetSelectionInteractorInputProtocol,
        wireframe: GovernanceChainSelectionWireframeProtocol,
        selectedChainId: ChainModel.Id?,
        selectedGovernanceType: GovernanceType?,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedChainId = selectedChainId
        self.selectedGovernanceType = selectedGovernanceType
        self.assetIconViewModelFactory = assetIconViewModelFactory

        super.init(
            interactor: interactor,
            baseWireframe: wireframe,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            localizationManager: localizationManager
        )
    }

    private func createViewModel(
        for chainAsset: ChainAsset,
        governanceType: GovernanceType
    ) -> SelectableIconDetailsListViewModel {
        let chain = chainAsset.chain
        let asset = chainAsset.asset

        let icon = ImageViewModelFactory.createChainIconOrDefault(from: chain.icon)
        let title = governanceType.title(for: chain)
        let isSelected = selectedChainId == chain.chainId && selectedGovernanceType == governanceType
        let balance = extractFormattedBalance(for: chainAsset) ?? ""

        return SelectableIconDetailsListViewModel(
            title: title,
            subtitle: balance,
            icon: icon,
            isSelected: isSelected
        )
    }

    override func updateView() {
        guard let assets = assets, isReadyForDisplay else {
            return
        }

        // show gov2 options first but not testnets
        availableOptions = assets.reduce(into: [Option]()) { accum, chainAsset in
            if chainAsset.chain.hasGovernanceV2, !chainAsset.chain.isTestnet {
                accum.append(.init(chainAsset: chainAsset, governanceType: .governanceV2))
            }
        }

        // then show gov1 options
        availableOptions = assets.reduce(into: availableOptions) { accum, chainAsset in
            if chainAsset.chain.hasGovernanceV1, !chainAsset.chain.isTestnet {
                accum.append(.init(chainAsset: chainAsset, governanceType: .governanceV1))
            }
        }

        // then show gov2 testnets
        availableOptions = assets.reduce(into: availableOptions) { accum, chainAsset in
            if chainAsset.chain.hasGovernanceV2, chainAsset.chain.isTestnet {
                accum.append(.init(chainAsset: chainAsset, governanceType: .governanceV2))
            }
        }

        // finally show gov1 testnets
        availableOptions = assets.reduce(into: availableOptions) { accum, chainAsset in
            if chainAsset.chain.hasGovernanceV1, chainAsset.chain.isTestnet {
                accum.append(.init(chainAsset: chainAsset, governanceType: .governanceV1))
            }
        }

        let viewModels = availableOptions.map {
            createViewModel(for: $0.chainAsset, governanceType: $0.governanceType)
        }

        updateViewModels(viewModels)

        view?.didReload()
    }

    override func handleAssetSelection(at index: Int) {
        guard let view = view else {
            return
        }

        let option = availableOptions[index]

        wireframe?.complete(
            on: view,
            option: .init(chain: option.chainAsset.chain, type: option.governanceType)
        )
    }
}
