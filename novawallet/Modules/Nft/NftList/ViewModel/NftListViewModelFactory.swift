import Foundation
import BigInt
import SoraFoundation

protocol NftListViewModelFactoryProtocol {
    func createViewModel(from model: NftChainModel, for locale: Locale) -> NftListViewModel
}

final class NftListViewModelFactory {
    let nftDownloadService: NftFileDownloadServiceProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>

    init(
        nftDownloadService: NftFileDownloadServiceProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.nftDownloadService = nftDownloadService
        self.quantityFormatter = quantityFormatter
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

    private func createLimitedIssuanceLabel(from serialNumber: Int32, totalNumber: Int32, locale: Locale) -> String {
        let serialNumberString = quantityFormatter.value(for: locale)
            .string(from: NSNumber(value: serialNumber)) ?? ""

        let totalNumberString = quantityFormatter.value(for: locale)
            .string(from: NSNumber(value: totalNumber)) ?? ""

        return R.string.localizable.nftListItemLimitedFormat(
            serialNumberString,
            totalNumberString,
            preferredLanguages: locale.rLanguages
        )
    }

    private func createUnlimitedIssuanceLabel(for locale: Locale) -> String {
        R.string.localizable.nftListItemUnlimited(preferredLanguages: locale.rLanguages)
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

        let mediaViewModel: NftMediaViewModelProtocol?

        if
            let imageUrlString = model.media,
            !imageUrlString.isEmpty,
            let imageUrl = URL(string: imageUrlString) {
            mediaViewModel = NftImageViewModel(url: imageUrl)
        } else if
            let metadataData = model.metadata,
            let metadataReference = String(data: metadataData, encoding: .utf8) {
            mediaViewModel = NftMediaViewModel(
                metadataReference: metadataReference,
                downloadService: nftDownloadService
            )
        } else {
            mediaViewModel = nil
        }

        return NftListStaticViewModel(name: name ?? "", label: label ?? "", media: mediaViewModel)
    }

    private func createUniquesMetadata(from model: NftModel, locale: Locale) -> NftListMetadataViewModelProtocol {
        if
            let metadataReferenceData = model.metadata,
            let reference = String(data: metadataReferenceData, encoding: .utf8) {
            let label: String

            if
                let totalIssuence = model.totalIssuance,
                let instanceIdString = model.instanceId,
                let instanceId = Int32(instanceIdString) {
                label = createLimitedIssuanceLabel(from: instanceId, totalNumber: totalIssuence, locale: locale)
            } else {
                label = createUnlimitedIssuanceLabel(for: locale)
            }

            return NftListUniquesViewModel(
                metadataReference: reference,
                metadataService: nftDownloadService,
                label: label
            )
        } else {
            return createStaticMetadata(from: model)
        }
    }

    private func createRMRKV1Metadata(from model: NftModel, locale: Locale) -> NftListMetadataViewModelProtocol {
        if
            let metadataReferenceData = model.metadata,
            let reference = String(data: metadataReferenceData, encoding: .utf8) {
            let mediaViewModel = NftMediaViewModel(metadataReference: reference, downloadService: nftDownloadService)

            let name = model.name ?? model.instanceId

            let label: String

            if
                let snString = model.label,
                let serialNumber = Int32(snString),
                let totalIssuance = model.totalIssuance {
                label = createLimitedIssuanceLabel(from: serialNumber, totalNumber: totalIssuance, locale: locale)
            } else {
                label = createUnlimitedIssuanceLabel(for: locale)
            }

            return NftListStaticViewModel(name: name ?? "", label: label, media: mediaViewModel)
        } else {
            return createStaticMetadata(from: model)
        }
    }

    private func createMedatadaViewModel(
        from model: NftChainModel,
        locale: Locale
    ) -> NftListMetadataViewModelProtocol {
        switch NftType(rawValue: model.nft.type) {
        case .uniques:
            return createUniquesMetadata(from: model.nft, locale: locale)
        case .rmrkV1:
            return createRMRKV1Metadata(from: model.nft, locale: locale)
        case .rmrkV2, .none:
            return createStaticMetadata(from: model.nft)
        }
    }
}

extension NftListViewModelFactory: NftListViewModelFactoryProtocol {
    func createViewModel(from model: NftChainModel, for locale: Locale) -> NftListViewModel {
        let identifier = model.nft.identifier
        let price = createPrice(from: model, locale: locale)
        let metadata = createMedatadaViewModel(from: model, locale: locale)

        return NftListViewModel(
            identifier: identifier,
            metadataViewModel: metadata,
            price: price,
            createdAt: model.nft.createdAt ?? Date()
        )
    }
}
