import Foundation

protocol GiftListViewModelFactoryProtocol {
    func createViewModel(
        for gifts: [GiftModel],
        chainAssets: [ChainAssetId: ChainAsset],
        syncingAccountIds: Set<AccountId>,
        locale: Locale
    ) -> [GiftListSectionModel]
}

final class GiftListViewModelFactory {
    let balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    let dateFormatter = DateFormatter.giftsList

    init(
        balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    ) {
        self.balanceViewModelFacade = balanceViewModelFacade
        self.assetIconViewModelFactory = assetIconViewModelFactory
    }
}

// MARK: - Private

private extension GiftListViewModelFactory {
    func createHeaderSection(with locale: Locale) -> GiftListSectionModel {
        GiftListSectionModel(
            section: .header,
            rows: [.header(locale)]
        )
    }

    func createGiftSection(
        for gifts: [GiftModel],
        chainAssets: [ChainAssetId: ChainAsset],
        syncingAccountIds: Set<AccountId>,
        locale: Locale
    ) -> GiftListSectionModel {
        let pendingGifts = gifts
            .filter { $0.status == .pending }
            .sorted { $0.creationDate > $1.creationDate }

        let claimedGifts = gifts
            .filter { $0.status == .claimed || $0.status == .reclaimed }
            .sorted { $0.creationDate > $1.creationDate }

        let giftRows = (pendingGifts + claimedGifts)
            .compactMap { createGiftModel(for: $0, using: chainAssets, syncingAccountIds: syncingAccountIds, locale) }
            .map { GiftListSectionModel.Row.gift($0) }

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.giftListGiftsSectionTitle()

        return GiftListSectionModel(
            section: .gifts(title),
            rows: giftRows
        )
    }

    func createGiftModel(
        for gift: GiftModel,
        using chainAssets: [ChainAssetId: ChainAsset],
        syncingAccountIds: Set<AccountId>,
        _ locale: Locale
    ) -> GiftListGiftViewModel? {
        let isSyncing = syncingAccountIds.contains(gift.giftAccountId)

        guard
            let chainAsset = chainAssets[gift.chainAssetId],
            let status = GiftListGiftViewModel.Status(
                from: gift.status,
                isSyncing: isSyncing
            )
        else { return nil }

        let assetDisplayInfo = chainAsset.assetDisplayInfo

        let amount = balanceViewModelFacade.amountFromValue(
            targetAssetInfo: assetDisplayInfo,
            value: gift.amount.decimal(assetInfo: assetDisplayInfo)
        ).value(for: locale)

        let tokenImageViewModel = assetIconViewModelFactory.createAssetIconViewModel(from: assetDisplayInfo)

        let giftImage = switch status {
        case .pending, .syncing:
            StaticImageViewModel(image: R.image.imageGiftPacked()!)
        case .claimed, .reclaimed:
            StaticImageViewModel(image: R.image.imageGiftUnpacked()!)
        }

        let subtitle: String? = switch status {
        case .pending:
            R.string(preferredLanguages: locale.rLanguages).localizable.giftCreatedDateFormat(
                dateFormatter.value(for: locale).string(from: gift.creationDate)
            )
        case .syncing:
            R.string(preferredLanguages: locale.rLanguages).localizable.commonSyncing()
        case .claimed:
            R.string(preferredLanguages: locale.rLanguages).localizable.giftStatusClaimed()
        case .reclaimed:
            R.string(preferredLanguages: locale.rLanguages).localizable.giftStatusReclaimed()
        }

        return GiftListGiftViewModel(
            identifier: gift.giftAccountId.toHex(),
            amount: amount,
            tokenImageViewModel: tokenImageViewModel,
            subtitle: subtitle,
            giftImageViewModel: giftImage,
            status: status
        )
    }
}

// MARK: - GiftListViewModelFactoryProtocol

extension GiftListViewModelFactory: GiftListViewModelFactoryProtocol {
    func createViewModel(
        for gifts: [GiftModel],
        chainAssets: [ChainAssetId: ChainAsset],
        syncingAccountIds: Set<AccountId>,
        locale: Locale
    ) -> [GiftListSectionModel] {
        guard !gifts.isEmpty else { return [] }

        return [
            createHeaderSection(with: locale),

            createGiftSection(
                for: gifts,
                chainAssets: chainAssets,
                syncingAccountIds: syncingAccountIds,
                locale: locale
            )
        ]
    }
}
