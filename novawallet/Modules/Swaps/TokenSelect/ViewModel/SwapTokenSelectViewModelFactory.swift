import Foundation
import Foundation_iOS

struct SwapTokenSelectListViewModelParams {
    let currentChainAssetId: ChainAssetId?
    let pendingChainAssetId: ChainAssetId?
    let counterpartSymbol: String?
    let isSearching: Bool
    let isFiltering: Bool
}

protocol SwapTokenSelectViewModelFactoryProtocol {
    func createListViewModel(
        from list: SwapTokenSelectList?,
        params: SwapTokenSelectListViewModelParams,
        locale: Locale
    ) -> SwapTokenSelectListViewModel

    func createChipViewModels(
        from chipRow: SwapTokenSelectChipRow,
        selectedNetworks: Set<ChainModel.Id>,
        locale: Locale
    ) -> [SwapTokenSelectChipViewModel]

    func createNetworkViewModels(
        from networks: [ChainModel],
        selectedNetworks: Set<ChainModel.Id>
    ) -> [SwapTokenSelectNetworkViewModel]
}

final class SwapTokenSelectViewModelFactory {
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    let formattingCache: AssetFormattingCacheProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>

    init(
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        formattingCache: AssetFormattingCacheProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
        self.networkViewModelFactory = networkViewModelFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory
        self.formattingCache = formattingCache
        self.quantityFormatter = quantityFormatter
    }
}

// MARK: Private

private extension SwapTokenSelectViewModelFactory {
    func createTokenRows(
        from items: [SwapTokenSelectItem],
        params: SwapTokenSelectListViewModelParams,
        locale: Locale
    ) -> [SwapTokenSelectRowViewModel] {
        items.map { item in
            .token(createTokenViewModel(from: item, params: params, locale: locale))
        }
    }

    func createTokenViewModel(
        from item: SwapTokenSelectItem,
        params: SwapTokenSelectListViewModelParams,
        locale: Locale
    ) -> SwapTokenSelectTokenViewModel {
        let chainAsset = item.chainAsset
        let network = networkViewModelFactory.createViewModel(from: chainAsset.chain)

        return SwapTokenSelectTokenViewModel(
            chainAssetId: chainAsset.chainAssetId,
            symbol: chainAsset.asset.symbol,
            networkName: network.name,
            tokenIcon: assetIconViewModelFactory.createAssetIconViewModel(from: chainAsset.assetDisplayInfo),
            networkIcon: network.icon,
            balance: createBalanceViewModel(from: item, locale: locale),
            isCurrent: chainAsset.chainAssetId == params.currentChainAssetId,
            isPending: chainAsset.chainAssetId == params.pendingChainAssetId
        )
    }

    func createBalanceViewModel(from item: SwapTokenSelectItem, locale: Locale) -> SwapTokenSelectBalanceViewModel? {
        guard item.hasBalance, let balance = item.balance else {
            return nil
        }

        let assetInfo = item.chainAsset.assetDisplayInfo

        let amount = formattingCache.formatDecimalAmount(balance, info: assetInfo, locale: locale)

        let price = item.priceData.map { priceData in
            balanceViewModelFactoryFacade.priceFromAmount(
                targetAssetInfo: assetInfo,
                amount: balance,
                priceData: priceData
            ).value(for: locale)
        }

        return SwapTokenSelectBalanceViewModel(amount: amount, price: price)
    }

    func createSections(
        from list: SwapTokenSelectList,
        params: SwapTokenSelectListViewModelParams,
        locale: Locale
    ) -> [SwapTokenSelectSectionViewModel] {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let yourRows = createTokenRows(from: list.yourTokens, params: params, locale: locale)
            + (list.balancesLoading ? [.loading] : [])

        let otherRows = createTokenRows(from: list.otherTokens, params: params, locale: locale)
        let notSwappableRows = createTokenRows(from: list.notSwappable, params: params, locale: locale)

        let sections = [
            SwapTokenSelectSectionViewModel(title: strings.swapsTokenSelectYourTokens(), rows: yourRows),
            SwapTokenSelectSectionViewModel(title: strings.swapsTokenSelectOtherTokens(), rows: otherRows),
            SwapTokenSelectSectionViewModel(
                title: strings.swapsTokenSelectNotSwappable(params.counterpartSymbol ?? ""),
                rows: notSwappableRows
            )
        ]

        return sections.filter { !$0.rows.isEmpty }
    }

    func createEmptyText(for params: SwapTokenSelectListViewModelParams, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        if params.isSearching {
            return strings.swapsTokenSelectSearchEmpty()
        } else if params.isFiltering {
            return strings.swapsTokenSelectFilterEmpty()
        } else {
            return strings.swapsTokenSelectEmpty()
        }
    }
}

// MARK: SwapTokenSelectViewModelFactoryProtocol

extension SwapTokenSelectViewModelFactory: SwapTokenSelectViewModelFactoryProtocol {
    func createListViewModel(
        from list: SwapTokenSelectList?,
        params: SwapTokenSelectListViewModelParams,
        locale: Locale
    ) -> SwapTokenSelectListViewModel {
        guard let list else {
            return .loading
        }

        guard !list.isEmpty else {
            return .empty(createEmptyText(for: params, locale: locale))
        }

        return .sections(createSections(from: list, params: params, locale: locale))
    }

    func createChipViewModels(
        from chipRow: SwapTokenSelectChipRow,
        selectedNetworks: Set<ChainModel.Id>,
        locale: Locale
    ) -> [SwapTokenSelectChipViewModel] {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let allChip = SwapTokenSelectChipViewModel(
            kind: .all,
            title: strings.commonAll(),
            icon: nil,
            isSelected: selectedNetworks.isEmpty
        )

        let networkChips = chipRow.networks.map { chain in
            let network = networkViewModelFactory.createViewModel(from: chain)

            return SwapTokenSelectChipViewModel(
                kind: .network(chain.chainId),
                title: network.name,
                icon: network.icon,
                isSelected: selectedNetworks.contains(chain.chainId)
            )
        }

        guard chipRow.remainingCount > 0 else {
            return [allChip] + networkChips
        }

        let remainingCount = quantityFormatter.value(for: locale).string(
            from: NSNumber(value: chipRow.remainingCount)
        ) ?? ""

        let moreChip = SwapTokenSelectChipViewModel(
            kind: .more,
            title: strings.swapsTokenSelectMoreNetworks(remainingCount),
            icon: R.image.iconAllNetworks().map { StaticImageViewModel(image: $0) },
            isSelected: false
        )

        return [allChip] + networkChips + [moreChip]
    }

    func createNetworkViewModels(
        from networks: [ChainModel],
        selectedNetworks: Set<ChainModel.Id>
    ) -> [SwapTokenSelectNetworkViewModel] {
        networks.map { chain in
            SwapTokenSelectNetworkViewModel(
                chainId: chain.chainId,
                network: networkViewModelFactory.createViewModel(from: chain),
                isSelected: selectedNetworks.contains(chain.chainId)
            )
        }
    }
}
