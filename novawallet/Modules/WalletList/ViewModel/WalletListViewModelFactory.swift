import Foundation
import SubstrateSdk
import SoraFoundation
import BigInt

struct WalletListAssetAccountPrice {
    let assetInfo: AssetBalanceDisplayInfo
    let balance: BigUInt
    let price: PriceData
}

struct WalletListAssetAccountInfo {
    let assetId: AssetModel.Id
    let assetInfo: AssetBalanceDisplayInfo
    let balance: BigUInt?
    let priceData: PriceData?
}

protocol WalletListViewModelFactoryProtocol {
    func createHeaderViewModel(
        from title: String,
        accountId: AccountId,
        prices: LoadableViewModelState<[WalletListAssetAccountPrice]>?,
        locale: Locale
    ) -> WalletListHeaderViewModel

    func createGroupViewModel(
        for chain: ChainModel,
        assets: [WalletListAssetAccountInfo],
        value: Decimal,
        connected: Bool,
        locale: Locale
    ) -> WalletListGroupViewModel

    func createAssetViewModel(
        chainId: ChainModel.Id,
        assetAccountInfo: WalletListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> WalletListAssetViewModel

    func createNftsViewModel(from nfts: [NftModel], locale: Locale) -> WalletListNftsViewModel
}

final class WalletListViewModelFactory {
    let priceFormatter: LocalizableResource<TokenFormatter>
    let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let percentFormatter: LocalizableResource<NumberFormatter>
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let nftDownloadService: NftFileDownloadServiceProtocol

    private lazy var cssColorFactory = CSSGradientFactory()

    init(
        priceFormatter: LocalizableResource<TokenFormatter>,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        nftDownloadService: NftFileDownloadServiceProtocol
    ) {
        self.priceFormatter = priceFormatter
        self.assetFormatterFactory = assetFormatterFactory
        self.percentFormatter = percentFormatter
        self.quantityFormatter = quantityFormatter
        self.nftDownloadService = nftDownloadService
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

    private func createPriceState(
        assetAccountInfo: WalletListAssetAccountInfo,
        locale: Locale
    ) -> LoadableViewModelState<WalletPriceViewModel> {
        if
            let priceString = assetAccountInfo.priceData?.price,
            let price = Decimal(string: priceString) {
            let priceChangeValue = (assetAccountInfo.priceData?.usdDayChange ?? 0.0) / 100.0
            let priceChangeString = percentFormatter.value(for: locale)
                .stringFromDecimal(priceChangeValue) ?? ""
            let priceString = priceFormatter.value(for: locale)
                .stringFromDecimal(price) ?? ""

            let priceChange: ValueDirection<String> = priceChangeValue >= 0.0
                ? .increase(value: priceChangeString) : .decrease(value: priceChangeString)
            return .loaded(value: WalletPriceViewModel(amount: priceString, change: priceChange))
        } else {
            return .loading
        }
    }

    private func createBalanceState(
        assetAccountInfo: WalletListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> (LoadableViewModelState<String>, LoadableViewModelState<String>) {
        if let balance = assetAccountInfo.balance {
            let assetInfo = assetAccountInfo.assetInfo

            let decimalBalance = Decimal.fromSubstrateAmount(
                balance,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let balanceFormatter = assetFormatterFactory.createDisplayFormatter(for: assetInfo)

            let balanceAmountString = balanceFormatter.value(for: locale).stringFromDecimal(
                decimalBalance
            ) ?? ""

            let balanceState = connected ? LoadableViewModelState.loaded(value: balanceAmountString) :
                LoadableViewModelState.cached(value: balanceAmountString)

            if
                let priceData = assetAccountInfo.priceData,
                let decimalPrice = Decimal(string: priceData.price) {
                let balanceValue = priceFormatter.value(for: locale).stringFromDecimal(
                    decimalBalance * decimalPrice
                ) ?? ""
                return (balanceState, .loaded(value: balanceValue))
            } else {
                return (balanceState, .loading)
            }

        } else {
            return (.loading, .loading)
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

    func createGroupViewModel(
        for chain: ChainModel,
        assets: [WalletListAssetAccountInfo],
        value: Decimal,
        connected: Bool,
        locale: Locale
    ) -> WalletListGroupViewModel {
        let assetViewModels = assets.map { asset in
            createAssetViewModel(
                chainId: chain.chainId,
                assetAccountInfo: asset,
                connected: connected,
                locale: locale
            )
        }

        let networkName = chain.name.uppercased()

        let iconViewModel = RemoteImageViewModel(url: chain.icon)

        let priceString = priceFormatter.value(for: locale).stringFromDecimal(value) ?? ""

        let color: GradientModel

        if
            let colorString = chain.color,
            let colorModel = cssColorFactory.createFromString(colorString) {
            color = colorModel
        } else {
            color = GradientModel.defaultGradient
        }

        return WalletListGroupViewModel(
            networkName: networkName,
            amount: .loaded(value: priceString),
            icon: iconViewModel,
            color: color,
            assets: assetViewModels
        )
    }

    func createAssetViewModel(
        chainId: ChainModel.Id,
        assetAccountInfo: WalletListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> WalletListAssetViewModel {
        let priceState = createPriceState(assetAccountInfo: assetAccountInfo, locale: locale)

        let (balanceState, balanceValueState) = createBalanceState(
            assetAccountInfo: assetAccountInfo,
            connected: connected,
            locale: locale
        )

        let assetInfo = assetAccountInfo.assetInfo

        let iconViewModel = assetInfo.icon.map { RemoteImageViewModel(url: $0) }

        return WalletListAssetViewModel(
            chainAssetId: ChainAssetId(chainId: chainId, assetId: assetAccountInfo.assetId),
            tokenName: assetInfo.symbol,
            icon: iconViewModel,
            price: priceState,
            balanceAmount: balanceState,
            balanceValue: balanceValueState
        )
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
                return NftMediaViewModel(metadataReference: metadataString, downloadService: nftDownloadService)
            }

            return nil
        }

        return WalletListNftsViewModel(totalCount: .loaded(value: count), mediaViewModels: viewModels)
    }
}
