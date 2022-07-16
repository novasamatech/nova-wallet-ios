import Foundation
import SubstrateSdk
import SoraFoundation
import BigInt

struct WalletListAssetAccountPrice {
    let assetInfo: AssetBalanceDisplayInfo
    let balance: BigUInt
    let price: PriceData
}

protocol WalletListViewModelFactoryProtocol: WalletListAssetViewModelFactoryProtocol {
    func createHeaderViewModel(
        from title: String,
        accountId: AccountId,
        prices: LoadableViewModelState<[WalletListAssetAccountPrice]>?,
        locale: Locale
    ) -> WalletListHeaderViewModel

    func createNftsViewModel(from nfts: [NftModel], locale: Locale) -> WalletListNftsViewModel
}

final class WalletListViewModelFactory: WalletListAssetViewModelFactory {
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let nftDownloadService: NftFileDownloadServiceProtocol

    init(
        priceFormatter: LocalizableResource<TokenFormatter>,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        nftDownloadService: NftFileDownloadServiceProtocol
    ) {
        self.quantityFormatter = quantityFormatter
        self.nftDownloadService = nftDownloadService

        super.init(priceFormatter: priceFormatter, assetFormatterFactory: assetFormatterFactory, percentFormatter: percentFormatter)
    }

    private lazy var iconGenerator = NovaIconGenerator()

    private func formatTotalPrice(from prices: [WalletListAssetAccountPrice], locale: Locale) -> String {
        let totalPrice = prices.reduce(Decimal(0)) { result, item in
            let balance = Decimal.fromSubstrateAmount(
                item.balance,
                precision: item.assetInfo.assetPrecision
            ) ?? 0.0

            let price = Decimal(string: item.price.price) ?? 0.0

            return result + balance * price
        }

        return priceFormatter.value(for: locale).stringFromDecimal(totalPrice) ?? ""
    }

    private func createTotalPrice(
        from prices: LoadableViewModelState<[WalletListAssetAccountPrice]>,
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

extension WalletListViewModelFactory: WalletListViewModelFactoryProtocol {
    func createHeaderViewModel(
        from title: String,
        accountId: AccountId,
        prices: LoadableViewModelState<[WalletListAssetAccountPrice]>?,
        locale: Locale
    ) -> WalletListHeaderViewModel {
        let icon = try? iconGenerator.generateFromAccountId(accountId)

        if let prices = prices {
            let totalPrice = createTotalPrice(from: prices, locale: locale)
            return WalletListHeaderViewModel(
                title: title,
                amount: totalPrice,
                icon: icon
            )
        } else {
            return WalletListHeaderViewModel(
                title: title,
                amount: .loading,
                icon: icon
            )
        }
    }

    func createNftsViewModel(from nfts: [NftModel], locale: Locale) -> WalletListNftsViewModel {
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

        return WalletListNftsViewModel(totalCount: .loaded(value: count), mediaViewModels: viewModels)
    }
}
