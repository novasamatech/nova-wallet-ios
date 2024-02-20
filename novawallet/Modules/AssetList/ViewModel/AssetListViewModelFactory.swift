import Foundation
import SubstrateSdk
import SoraFoundation
import BigInt

struct AssetListAssetAccountPrice {
    let assetInfo: AssetBalanceDisplayInfo
    let balance: BigUInt
    let price: PriceData
}

struct AssetListHeaderParams {
    struct Wallet {
        let walletIdenticon: Data?
        let walletType: MetaAccountModelType
        let walletConnectSessionsCount: Int
        let hasWalletsUpdates: Bool
    }

    let title: String
    let wallet: Wallet
    let prices: LoadableViewModelState<[AssetListAssetAccountPrice]>?
    let locks: [AssetListAssetAccountPrice]?
    let hasSwaps: Bool
}

protocol AssetListViewModelFactoryProtocol: AssetListAssetViewModelFactoryProtocol {
    func createHeaderViewModel(params: AssetListHeaderParams, locale: Locale) -> AssetListHeaderViewModel

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

    private func calculateTotalPrice(from prices: [AssetListAssetAccountPrice]) -> Decimal {
        prices.reduce(Decimal(0)) { result, item in
            let balance = Decimal.fromSubstrateAmount(
                item.balance,
                precision: item.assetInfo.assetPrecision
            ) ?? 0.0

            let price = Decimal(string: item.price.price) ?? 0.0

            return result + balance * price
        }
    }

    private func createTotalPriceString(
        from price: Decimal,
        priceData: PriceData?,
        locale: Locale
    ) -> String {
        let currencyId = priceData?.currencyId ?? currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        let priceFormatter = assetFormatterFactory.createTotalPriceFormatter(for: assetDisplayInfo)

        return priceFormatter.value(for: locale).stringFromDecimal(price) ?? ""
    }

    private func createTotalPrice(
        from prices: LoadableViewModelState<[AssetListAssetAccountPrice]>,
        locale: Locale
    ) -> LoadableViewModelState<AssetListTotalAmountViewModel> {
        switch prices {
        case .loading:
            return .loading
        case let .cached(value):
            let formattedPrice = createTotalPriceString(
                from: calculateTotalPrice(from: value),
                priceData: value.first?.price,
                locale: locale
            )

            return .cached(value: .init(amount: formattedPrice, decimalSeparator: locale.decimalSeparator))
        case let .loaded(value):
            let formattedPrice = createTotalPriceString(
                from: calculateTotalPrice(from: value),
                priceData: value.first?.price,
                locale: locale
            )

            return .loaded(value: .init(amount: formattedPrice, decimalSeparator: locale.decimalSeparator))
        }
    }
}

extension AssetListViewModelFactory: AssetListViewModelFactoryProtocol {
    func createHeaderViewModel(params: AssetListHeaderParams, locale: Locale) -> AssetListHeaderViewModel {
        let icon = params.wallet.walletIdenticon.flatMap { try? iconGenerator.generateFromAccountId($0) }
        let walletSwitch = WalletSwitchViewModel(
            type: WalletsListSectionViewModel.SectionType(walletType: params.wallet.walletType),
            iconViewModel: icon.map { DrawableIconViewModel(icon: $0) },
            hasNotification: params.wallet.hasWalletsUpdates
        )

        let walletConnectSessionsCount = params.wallet.walletConnectSessionsCount
        let formattedWalletConnectSessionsCount = walletConnectSessionsCount > 0 ?
            quantityFormatter.value(for: locale).string(from: NSNumber(value: walletConnectSessionsCount)) :
            nil

        if let prices = params.prices {
            let totalPrice = createTotalPrice(from: prices, locale: locale)
            return AssetListHeaderViewModel(
                walletConnectSessionsCount: formattedWalletConnectSessionsCount,
                title: params.title,
                amount: totalPrice,
                locksAmount: params.locks.map { lock in
                    formatPrice(
                        amount: calculateTotalPrice(from: lock),
                        priceData: lock.first?.price,
                        locale: locale
                    )
                },
                walletSwitch: walletSwitch,
                hasSwaps: params.hasSwaps
            )
        } else {
            return AssetListHeaderViewModel(
                walletConnectSessionsCount: formattedWalletConnectSessionsCount,
                title: params.title,
                amount: .loading,
                locksAmount: nil,
                walletSwitch: walletSwitch,
                hasSwaps: params.hasSwaps
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
