import Foundation
import BigInt

protocol NftListViewModelFactoryProtocol {
    func createViewModel(from model: NftChainModel, for locale: Locale) -> NftListViewModel
}

final class NftListViewModelFactory {
    let nftDownloadService: NftFileDownloadServiceProtocol

    init(nftDownloadService: NftFileDownloadServiceProtocol) {
        self.nftDownloadService = nftDownloadService
    }

    private var balanceViewModelFactories: [ChainAssetId: BalanceViewModelFactory] = [:]

    private func getBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactory {
        let chainAssetId = chainAsset.chainAssetId

        if let viewModelFactory = balanceViewModelFactories[chainAssetId] {
            return viewModelFactory
        }

        let assetInfo = chainAsset.assetDisplayInfo
        let viewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)
        balanceViewModelFactories[chainAssetId] = viewModelFactory

        return viewModelFactory
    }

    private func createPrice(from model: NftChainModel, locale: Locale) -> BalanceViewModelProtocol? {
        if let priceString = model.nft.price, let priceInPlanks = BigUInt(priceString), priceInPlanks > 0 {
            let assetInfo = model.chainAsset.assetDisplayInfo
            let priceDecimal = Decimal.fromSubstrateAmount(priceInPlanks, precision: assetInfo.assetPrecision) ?? 0

            let balanceViewModelFactory = getBalanceViewModelFactory(for: model.chainAsset)
            return balanceViewModelFactory.balanceFromPrice(priceDecimal, priceData: model.price).value(for: locale)
        } else {
            return nil
        }
    }

    private func createStaticMetadata(from model: NftModel) -> NftListMetadataViewModelProtocol {
        let name = model.name ?? model.instanceId
        let label = model.label ?? model.collectionId

        if let mediaString = model.media, let url = URL(string: mediaString) {
            let viewModel = NftImageViewModel(url: url)
            return NftListStaticViewModel(name: name ?? "", label: label ?? "", media: viewModel)
        } else {
            return NftListStaticViewModel(name: name ?? "", label: label ?? "", media: nil)
        }
    }

    private func createUniquesMetadata(from model: NftModel) -> NftListMetadataViewModelProtocol {
        if
            let metadataReferenceData = model.metadata,
            let reference = String(data: metadataReferenceData, encoding: .utf8) {
            return NftListUniquesViewModel(metadataReference: reference, metadataService: nftDownloadService)
        } else {
            return createStaticMetadata(from: model)
        }
    }

    private func createRMRKV1Metadata(from model: NftModel) -> NftListMetadataViewModelProtocol {
        if
            let metadataReferenceData = model.metadata,
            let reference = String(data: metadataReferenceData, encoding: .utf8) {
            let mediaViewModel = NftMediaViewModel(metadataReference: reference, downloadService: nftDownloadService)

            let name = model.name ?? model.instanceId
            let label = model.label ?? model.collectionId

            return NftListStaticViewModel(name: name ?? "", label: label ?? "", media: mediaViewModel)
        } else {
            return createStaticMetadata(from: model)
        }
    }

    private func createMedatadaViewModel(from model: NftChainModel) -> NftListMetadataViewModelProtocol {
        switch NftType(rawValue: model.nft.type) {
        case .uniques:
            return createUniquesMetadata(from: model.nft)
        case .rmrkV1:
            return createRMRKV1Metadata(from: model.nft)
        case .rmrkV2, .none:
            return createStaticMetadata(from: model.nft)
        }
    }
}

extension NftListViewModelFactory: NftListViewModelFactoryProtocol {
    func createViewModel(from model: NftChainModel, for locale: Locale) -> NftListViewModel {
        let identifier = model.nft.identifier
        let price = createPrice(from: model, locale: locale)
        let metadata = createMedatadaViewModel(from: model)

        return NftListViewModel(
            identifier: identifier,
            metadataViewModel: metadata,
            price: price,
            createdAt: model.nft.createdAt ?? Date()
        )
    }
}
