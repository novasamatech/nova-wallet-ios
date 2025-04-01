import Foundation
import Foundation_iOS

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
    private let balanceMapperFactory: GovBalanceCalculatorFactoryProtocol

    init(
        interactor: ChainAssetSelectionInteractorInputProtocol,
        wireframe: GovernanceChainSelectionWireframeProtocol,
        selectedChainId: ChainModel.Id?,
        selectedGovernanceType: GovernanceType?,
        balanceMapperFactory: GovBalanceCalculatorFactoryProtocol,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedChainId = selectedChainId
        self.selectedGovernanceType = selectedGovernanceType
        self.assetIconViewModelFactory = assetIconViewModelFactory
        self.balanceMapperFactory = balanceMapperFactory

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

        let icon = ImageViewModelFactory.createChainIconOrDefault(from: chain.icon)
        let title = governanceType.title(for: chain)
        let isSelected = selectedChainId == chain.chainId && selectedGovernanceType == governanceType

        let balanceMapper = balanceMapperFactory.createCalculator(for: governanceType)
        let balance = extractFormattedBalance(for: chainAsset, balanceMapper: balanceMapper) ?? ""

        return SelectableIconDetailsListViewModel(
            title: title,
            subtitle: balance,
            icon: icon,
            isSelected: isSelected
        )
    }

    override func updateAvailableOptions() {
        guard let assets = assets, isReadyForDisplay else {
            return
        }

        let gov2Mapper = balanceMapperFactory.createCalculator(for: .governanceV2)
        let gov1Mapper = balanceMapperFactory.createCalculator(for: .governanceV1)

        // show gov2 options first but not testnets
        let gov2Options: [Option] = assets.compactMap { chainAsset in
            if chainAsset.chain.hasGovernanceV2, !chainAsset.chain.isTestnet {
                Option(chainAsset: chainAsset, governanceType: .governanceV2)
            } else {
                nil
            }
        }.sorted(by: { orderAssets($0.chainAsset, chainAsset2: $1.chainAsset, balanceMapper: gov2Mapper) })

        // then show gov1 options
        let gov1Options: [Option] = assets.compactMap { chainAsset in
            if chainAsset.chain.hasGovernanceV1, !chainAsset.chain.isTestnet {
                Option(chainAsset: chainAsset, governanceType: .governanceV1)
            } else {
                nil
            }
        }.sorted(by: { orderAssets($0.chainAsset, chainAsset2: $1.chainAsset, balanceMapper: gov1Mapper) })

        // then show gov2 testnets
        let gov2Testnets: [Option] = assets.compactMap { chainAsset in
            if chainAsset.chain.hasGovernanceV2, chainAsset.chain.isTestnet {
                Option(chainAsset: chainAsset, governanceType: .governanceV2)
            } else {
                nil
            }
        }.sorted(by: { orderAssets($0.chainAsset, chainAsset2: $1.chainAsset, balanceMapper: gov2Mapper) })

        // finally show gov1 testnets
        let gov1Testnets: [Option] = assets.compactMap { chainAsset in
            if chainAsset.chain.hasGovernanceV1, chainAsset.chain.isTestnet {
                Option(chainAsset: chainAsset, governanceType: .governanceV1)
            } else {
                nil
            }
        }.sorted(by: { orderAssets($0.chainAsset, chainAsset2: $1.chainAsset, balanceMapper: gov1Mapper) })

        availableOptions = gov2Options + gov1Options + gov2Testnets + gov1Testnets
    }

    override func updateView() {
        guard assets != nil, isReadyForDisplay else {
            return
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
