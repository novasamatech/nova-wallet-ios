import Foundation
import BigInt
import Foundation_iOS

protocol NftListViewModelFactoryProtocol {
    func createViewModel(from model: NftChainModel, for locale: Locale) -> NftListViewModel
}

final class NftListViewModelFactory {
    let nftDownloadService: NftFileDownloadServiceProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    init(
        nftDownloadService: NftFileDownloadServiceProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        self.nftDownloadService = nftDownloadService
        self.quantityFormatter = quantityFormatter
        self.priceAssetInfoFactory = priceAssetInfoFactory
    }

    private var balanceViewModelFactories: [ChainAssetId: BalanceViewModelFactory] = [:]

    private func getBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactory {
        let chainAssetId = chainAsset.chainAssetId

        if let viewModelFactory = balanceViewModelFactories[chainAssetId] {
            return viewModelFactory
        }

        let assetInfo = chainAsset.assetDisplayInfo
        let viewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        balanceViewModelFactories[chainAssetId] = viewModelFactory

        return viewModelFactory
    }

    private func getUnitsBalanceViewModelFactory() -> BalanceViewModelFactory {
        let chainAssetId = ChainAssetId(chainId: "", assetId: 0)

        if let viewModelFactory = balanceViewModelFactories[chainAssetId] {
            return viewModelFactory
        }

        let assetInfo = AssetBalanceDisplayInfo.units(for: 0)
        let viewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        balanceViewModelFactories[chainAssetId] = viewModelFactory

        return viewModelFactory
    }

    private func createLimitedIssuanceLabel(from serialNumber: Int32, totalNumber: BigUInt, locale: Locale) -> String {
        let serialNumberString = quantityFormatter.value(for: locale)
            .string(from: NSNumber(value: serialNumber)) ?? ""

        let unitsViewModelFactory = getUnitsBalanceViewModelFactory()
        let totalNumberString = unitsViewModelFactory.unitsFromValue(totalNumber.decimal()).value(for: locale)

        return R.string.localizable.nftListItemLimitedFormat(
            serialNumberString,
            totalNumberString,
            preferredLanguages: locale.rLanguages
        )
    }

    private func createUnlimitedIssuanceLabel(for locale: Locale) -> String {
        R.string.localizable.nftListItemUnlimited(preferredLanguages: locale.rLanguages)
    }

    private func createNonFungiblePrice(from model: NftChainModel, locale: Locale) -> BalanceViewModelProtocol? {
        if let priceString = model.nft.price, let priceInPlanks = BigUInt(priceString), priceInPlanks > 0 {
            let assetInfo = model.chainAsset.assetDisplayInfo
            let priceDecimal = Decimal.fromSubstrateAmount(priceInPlanks, precision: assetInfo.assetPrecision) ?? 0

            let balanceViewModelFactory = getBalanceViewModelFactory(for: model.chainAsset)
            return balanceViewModelFactory.balanceFromPrice(priceDecimal, priceData: model.price).value(for: locale)
        } else {
            return nil
        }
    }

    private func createFungiblePrice(from model: NftChainModel, locale: Locale) -> BalanceViewModelProtocol? {
        guard
            let price = model.nft.price.flatMap({ BigUInt($0)?.decimal(precision: model.chainAsset.asset.precision) }),
            let priceUnits = model.nft.priceUnits.flatMap({ BigUInt($0) })?.decimal() else {
            return nil
        }

        let viewModelFactory = getBalanceViewModelFactory(for: model.chainAsset)
        let viewModel = viewModelFactory.balanceFromPrice(price, priceData: model.price).value(for: locale)

        let priceUnitsString = viewModelFactory.unitsFromValue(priceUnits).value(for: locale)

        let amount = R.string.localizable.nftFungiblePrice(
            priceUnitsString,
            viewModel.amount,
            preferredLanguages: locale.rLanguages
        )

        return BalanceViewModel(amount: amount, price: viewModel.price)
    }

    private func createPrice(from model: NftChainModel, locale: Locale) -> BalanceViewModelProtocol? {
        switch NftType(rawValue: model.nft.type) {
        case .rmrkV1, .rmrkV2, .uniques, .kodadot, .unique, .none:
            return createNonFungiblePrice(from: model, locale: locale)
        case .pdc20:
            return createFungiblePrice(from: model, locale: locale)
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
                aliases: NftMediaAlias.list,
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
                let totalIssuence = model.issuanceTotal,
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

    private func createRMRKV2Metadata(from model: NftModel, locale: Locale) -> NftListMetadataViewModelProtocol {
        if
            let metadataReferenceData = model.metadata,
            let reference = String(data: metadataReferenceData, encoding: .utf8) {
            let label: String

            if
                let snString = model.label,
                let serialNumber = Int32(snString),
                let totalIssuance = model.issuanceTotal,
                totalIssuance > 0 {
                label = createLimitedIssuanceLabel(from: serialNumber, totalNumber: totalIssuance, locale: locale)
            } else {
                label = createUnlimitedIssuanceLabel(for: locale)
            }

            return NftListRMRKV2ViewModel(
                metadataReference: reference,
                metadataService: nftDownloadService,
                label: label,
                imageUrl: model.media,
                fallbackName: model.name
            )
        } else {
            return createStaticMetadata(from: model)
        }
    }

    private func createRMRKV1Metadata(from model: NftModel, locale: Locale) -> NftListMetadataViewModelProtocol {
        if
            let metadataReferenceData = model.metadata,
            let reference = String(data: metadataReferenceData, encoding: .utf8) {
            let mediaViewModel = NftMediaViewModel(
                metadataReference: reference,
                aliases: NftMediaAlias.list,
                downloadService: nftDownloadService
            )

            let name = model.name ?? model.instanceId

            let label: String

            if
                let snString = model.label,
                let serialNumber = Int32(snString),
                let totalIssuance = model.issuanceTotal,
                totalIssuance > 0 {
                label = createLimitedIssuanceLabel(from: serialNumber, totalNumber: totalIssuance, locale: locale)
            } else {
                label = createUnlimitedIssuanceLabel(for: locale)
            }

            return NftListStaticViewModel(name: name ?? "", label: label, media: mediaViewModel)
        } else {
            return createStaticMetadata(from: model)
        }
    }

    private func createPdc20Metadata(
        from model: NftModel,
        locale: Locale
    ) -> NftListMetadataViewModelProtocol {
        let name = model.name ?? model.instanceId

        let mediaViewModel: NftMediaViewModelProtocol?

        if
            let imageUrlString = model.media,
            !imageUrlString.isEmpty,
            let imageUrl = URL(string: imageUrlString) {
            mediaViewModel = NftImageViewModel(url: imageUrl)
        } else {
            mediaViewModel = nil
        }

        let label: String?

        if
            let amount = model.issuanceMyAmount,
            let totalSupply = model.issuanceTotal {
            let viewModelFactory = getUnitsBalanceViewModelFactory()
            let amountString = viewModelFactory.unitsFromValue(amount.decimal()).value(for: locale)
            let totalSupplyString = viewModelFactory.unitsFromValue(totalSupply.decimal()).value(for: locale)

            label = R.string.localizable.nftIssuanceFungibleFormat(
                amountString,
                totalSupplyString,
                preferredLanguages: locale.rLanguages
            )
        } else {
            label = model.issuanceMyAmount.map { String($0) }
        }

        return NftListStaticViewModel(name: name ?? "", label: label ?? "", media: mediaViewModel)
    }

    private func createKodaDotViewModel(
        from model: NftModel,
        locale: Locale
    ) -> NftListMetadataViewModelProtocol {
        let name = model.name ?? model.instanceId ?? ""

        let label: String

        if
            let snString = model.label,
            let serialNumber = Int32(snString),
            let totalIssuance = model.issuanceTotal,
            totalIssuance > 0 {
            label = createLimitedIssuanceLabel(from: serialNumber, totalNumber: totalIssuance, locale: locale)
        } else {
            label = createUnlimitedIssuanceLabel(for: locale)
        }

        let mediaViewModel = KodadotMediaViewModelFactory.createMediaViewModel(
            from: model.media,
            using: nftDownloadService
        )

        return NftListStaticViewModel(name: name, label: label, media: mediaViewModel)
    }

    private func createUniqueViewModel(
        from model: NftModel,
        locale: Locale
    ) -> NftListMetadataViewModelProtocol {
        let name = model.name ?? model.instanceId ?? ""
        let label = createUnlimitedIssuanceLabel(for: locale)

        let mediaViewModel: NftMediaViewModelProtocol?
        if
            let imageUrlString = model.media,
            let imageUrl = URL(string: imageUrlString) {
            mediaViewModel = NftImageViewModel(url: imageUrl)
        } else {
            mediaViewModel = nil
        }

        return NftListStaticViewModel(
            name: name,
            label: label,
            media: mediaViewModel
        )
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
        case .rmrkV2:
            return createRMRKV2Metadata(from: model.nft, locale: locale)
        case .pdc20:
            return createPdc20Metadata(from: model.nft, locale: locale)
        case .kodadot:
            return createKodaDotViewModel(from: model.nft, locale: locale)
        case .unique:
            return createUniqueViewModel(from: model.nft, locale: locale)
        case .none:
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
