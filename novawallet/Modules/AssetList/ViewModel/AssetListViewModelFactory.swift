import Foundation
import SubstrateSdk
import Foundation_iOS
import BigInt

struct AssetListAssetAccountPrice {
    let assetInfo: AssetBalanceDisplayInfo
    let balance: BigUInt
    let price: PriceData
}

struct AssetListHeaderParams {
    struct Wallet {
        let identifier: String
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
    func createHeaderViewModel(
        params: AssetListHeaderParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListHeaderViewModel

    func createOrganizerViewModel(
        from nfts: [NftModel],
        operations: [Multisig.PendingOperation],
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListOrganizerViewModel?
}

final class AssetListViewModelFactory: AssetListAssetViewModelFactory {
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let nftDownloadService: NftFileDownloadServiceProtocol

    init(
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        nftDownloadService: NftFileDownloadServiceProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.quantityFormatter = quantityFormatter
        self.nftDownloadService = nftDownloadService

        super.init(
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: assetFormatterFactory,
            percentFormatter: percentFormatter,
            assetIconViewModelFactory: assetIconViewModelFactory,
            currencyManager: currencyManager
        )
    }

    private lazy var iconGenerator = NovaIconGenerator()
}

// MARK: - Private

private extension AssetListViewModelFactory {
    func formatPrice(amount: Decimal, priceData: PriceData?, locale: Locale) -> String {
        let currencyId = priceData?.currencyId ?? currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        let priceFormatter = assetFormatterFactory.createAssetPriceFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }

    func calculateTotalPrice(from prices: [AssetListAssetAccountPrice]) -> Decimal {
        prices.reduce(Decimal(0)) { result, item in
            let balance = Decimal.fromSubstrateAmount(
                item.balance,
                precision: item.assetInfo.assetPrecision
            ) ?? 0.0

            let price = Decimal(string: item.price.price) ?? 0.0

            return result + balance * price
        }
    }

    func createTotalPriceString(
        from price: Decimal,
        priceData: PriceData?,
        locale: Locale
    ) -> String {
        let currencyId = priceData?.currencyId ?? currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)

        let priceFormatter = assetFormatterFactory.createAssetPriceFormatter(
            for: assetDisplayInfo,
            useSuffixForBigNumbers: false
        )

        return priceFormatter.value(for: locale).stringFromDecimal(price) ?? ""
    }

    func createTotalPrice(
        from prices: LoadableViewModelState<[AssetListAssetAccountPrice]>,
        genericParams: ViewModelFactoryGenericParams
    ) -> LoadableViewModelState<SecuredViewModel<AssetListTotalAmountViewModel>> {
        switch prices {
        case .loading:
            return .loading
        case let .cached(value):
            let formattedPrice = createTotalPriceString(
                from: calculateTotalPrice(from: value),
                priceData: value.first?.price,
                locale: genericParams.locale
            )
            let viewModel = AssetListTotalAmountViewModel(
                amount: formattedPrice,
                decimalSeparator: genericParams.locale.decimalSeparator
            )

            return .cached(value: .wrapped(viewModel, with: genericParams.privacyModeEnabled))
        case let .loaded(value):
            let formattedPrice = createTotalPriceString(
                from: calculateTotalPrice(from: value),
                priceData: value.first?.price,
                locale: genericParams.locale
            )
            let viewModel = AssetListTotalAmountViewModel(
                amount: formattedPrice,
                decimalSeparator: genericParams.locale.decimalSeparator
            )

            return .loaded(value: .wrapped(viewModel, with: genericParams.privacyModeEnabled))
        }
    }

    func createLocksViewModel(
        for locks: [AssetListAssetAccountPrice]?,
        genericParams: ViewModelFactoryGenericParams
    ) -> SecuredViewModel<String>? {
        guard let amount = locks.map({ lock in
            formatPrice(
                amount: calculateTotalPrice(from: lock),
                priceData: lock.first?.price,
                locale: genericParams.locale
            )
        }) else { return nil }

        return .wrapped(amount, with: genericParams.privacyModeEnabled)
    }

    func createNftsViewModel(
        from nfts: [NftModel],
        locale: Locale
    ) -> AssetListNftsViewModel {
        let numberOfNfts = NSNumber(value: nfts.count)
        let count = quantityFormatter.value(for: locale).string(from: numberOfNfts) ?? ""

        let viewModels: [NftMediaViewModelProtocol] = nfts.filter { nft in
            nft.media != nil || nft.metadata != nil
        }.prefix(3).compactMap { nft in
            if
                let media = nft.media,
                let gatewayImageUrl = nftDownloadService.imageUrl(from: media) {
                return NftImageViewModel(url: gatewayImageUrl)
            }

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

        return AssetListNftsViewModel(
            totalCount: .loaded(
                value: TitleIconViewModel(title: count, icon: nil)
            ),
            mediaViewModels: viewModels
        )
    }

    func createMultisigOperationsViewModel(
        from operations: [Multisig.PendingOperation],
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListMultisigOperationsViewModel {
        let numberOfOperations = NSNumber(value: operations.count)
        let count = quantityFormatter.value(for: genericParams.locale).string(from: numberOfOperations) ?? ""

        return AssetListMultisigOperationsViewModel(
            totalCount: .wrapped(
                TitleIconViewModel(title: count, icon: R.image.iconPending()),
                with: genericParams.privacyModeEnabled
            )
        )
    }
}

// MARK: - AssetListViewModelFactoryProtocol

extension AssetListViewModelFactory: AssetListViewModelFactoryProtocol {
    func createHeaderViewModel(
        params: AssetListHeaderParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListHeaderViewModel {
        let icon = params.wallet.walletIdenticon.flatMap { try? iconGenerator.generateFromAccountId($0) }
        let walletSwitch = WalletSwitchViewModel(
            identifier: params.wallet.identifier,
            type: WalletsListSectionViewModel.SectionType(walletType: params.wallet.walletType),
            iconViewModel: icon.map { DrawableIconViewModel(icon: $0) },
            hasNotification: params.wallet.hasWalletsUpdates
        )

        let walletConnectSessionsCount = params.wallet.walletConnectSessionsCount
        let formattedWalletConnectSessionsCount: String? = if walletConnectSessionsCount > 0 {
            quantityFormatter.value(
                for: genericParams.locale
            ).string(from: NSNumber(value: walletConnectSessionsCount))
        } else {
            nil
        }

        if let prices = params.prices {
            let totalPrice = createTotalPrice(
                from: prices,
                genericParams: genericParams
            )
            let locksAmount = createLocksViewModel(
                for: params.locks,
                genericParams: genericParams
            )

            return AssetListHeaderViewModel(
                walletConnectSessionsCount: formattedWalletConnectSessionsCount,
                title: params.title,
                amount: totalPrice,
                locksAmount: locksAmount,
                walletSwitch: walletSwitch,
                hasSwaps: params.hasSwaps,
                privacyModelEnabled: genericParams.privacyModeEnabled
            )
        } else {
            return AssetListHeaderViewModel(
                walletConnectSessionsCount: formattedWalletConnectSessionsCount,
                title: params.title,
                amount: .loading,
                locksAmount: nil,
                walletSwitch: walletSwitch,
                hasSwaps: params.hasSwaps,
                privacyModelEnabled: genericParams.privacyModeEnabled
            )
        }
    }

    func createOrganizerViewModel(
        from nfts: [NftModel],
        operations: [Multisig.PendingOperation],
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListOrganizerViewModel? {
        var items: [AssetListOrganizerItemViewModel] = []

        if !nfts.isEmpty {
            items.append(
                .nfts(
                    .wrapped(
                        createNftsViewModel(
                            from: nfts,
                            locale: genericParams.locale
                        ),
                        with: genericParams.privacyModeEnabled
                    )
                )
            )
        }
        if !operations.isEmpty {
            let multisigOperationsViewModel = createMultisigOperationsViewModel(
                from: operations,
                genericParams: genericParams
            )
            items.append(.pendingTransactions(multisigOperationsViewModel))
        }

        guard !items.isEmpty else { return nil }

        return AssetListOrganizerViewModel(items: items)
    }
}
