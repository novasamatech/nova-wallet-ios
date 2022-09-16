import Foundation
import SubstrateSdk
import SoraFoundation
import BigInt

struct AssetListAssetAccountPrice {
    let assetInfo: AssetBalanceDisplayInfo
    let balance: BigUInt
    let price: PriceData
}

protocol AssetListViewModelFactoryProtocol: AssetListAssetViewModelFactoryProtocol {
    func createHeaderViewModel(
        from title: String,
        walletIdenticon: Data?,
        walletType: MetaAccountModelType,
        prices: LoadableViewModelState<[AssetListAssetAccountPrice]>?,
        locale: Locale
    ) -> AssetListHeaderViewModel

    func createNftsViewModel(from nfts: [NftModel], locale: Locale) -> AssetListNftsViewModel
}

final class AssetListViewModelFactory: AssetListAssetViewModelFactory {
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let nftDownloadService: NftFileDownloadServiceProtocol

    init(
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        nftDownloadService: NftFileDownloadServiceProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.quantityFormatter = quantityFormatter
        self.nftDownloadService = nftDownloadService

        super.init(
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: assetFormatterFactory,
            percentFormatter: percentFormatter,
            currencyManager: currencyManager
        )
    }

    private lazy var iconGenerator = NovaIconGenerator()

    private func formatTotalPrice(from prices: [AssetListAssetAccountPrice], locale: Locale) -> String {
        let totalPrice = prices.reduce(Decimal(0)) { result, item in
            let balance = Decimal.fromSubstrateAmount(
                item.balance,
                precision: item.assetInfo.assetPrecision
            ) ?? 0.0

            let price = Decimal(string: item.price.price) ?? 0.0

            return result + balance * price
        }

        return formatPrice(amount: totalPrice, priceData: prices.first?.price, locale: locale)
    }

    private func createTotalPrice(
        from prices: LoadableViewModelState<[AssetListAssetAccountPrice]>,
        locale: Locale
    ) -> LoadableViewModelState<String> {
        switch prices {
        case .loading:
            return .loading
        case let .cached(value):
            let formattedPrice = formatTotalPrice(from: value, locale: locale)
            return .cached(value: formattedPrice)
        case let .loaded(value):
            let formattedPrice = formatTotalPrice(from: value, locale: locale)
            return .loaded(value: formattedPrice)
        }
    }
}

extension AssetListViewModelFactory: AssetListViewModelFactoryProtocol {
    func createHeaderViewModel(
        from title: String,
        walletIdenticon: Data?,
        walletType: MetaAccountModelType,
        prices: LoadableViewModelState<[AssetListAssetAccountPrice]>?,
        locale: Locale
    ) -> AssetListHeaderViewModel {
        let icon = walletIdenticon.flatMap { try? iconGenerator.generateFromAccountId($0) }
        let walletSwitch = WalletSwitchViewModel(
            type: WalletsListSectionViewModel.SectionType(walletType: walletType),
            iconViewModel: icon.map { DrawableIconViewModel(icon: $0) }
        )

        if let prices = prices {
            let totalPrice = createTotalPrice(from: prices, locale: locale)
            return AssetListHeaderViewModel(
                title: title,
                amount: totalPrice,
                walletSwitch: walletSwitch
            )
        } else {
            return AssetListHeaderViewModel(
                title: title,
                amount: .loading,
                walletSwitch: walletSwitch
            )
        }
    }

    func createNftsViewModel(from nfts: [NftModel], locale: Locale) -> AssetListNftsViewModel {
        let numberOfNfts = NSNumber(value: nfts.count)
        let count = quantityFormatter.value(for: locale).string(from: numberOfNfts) ?? ""

        let viewModels: [NftMediaViewModelProtocol] = nfts.filter { nft in
            nft.media != nil || nft.metadata != nil
        }.prefix(3).compactMap { nft in
            if let media = nft.media, let url = URL(string: media) {
                return NftImageViewModel(url: url)
            }

            if let metadata = nft.metadata, let metadataString = String(data: metadata, encoding: .utf8) {
                return NftMediaViewModel(
                    metadataReference: metadataString,
                    aliases: NftMediaAlias.list,
                    downloadService: nftDownloadService
                )
            }

            return nil
        }

        return AssetListNftsViewModel(totalCount: .loaded(value: count), mediaViewModels: viewModels)
    }
}
