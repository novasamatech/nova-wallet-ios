import SoraFoundation
import SubstrateSdk
import CommonWallet

protocol TransactionHistoryViewModelFactory2Protocol {
    func createItemFromData(
        _ data: AssetTransactionData,
        locale: Locale
    ) throws -> TransactionItemViewModel

    func createGroupModel(_ data: [AssetTransactionData], locale: Locale) throws -> [String: [TransactionItemViewModel]]
}

final class TransactionHistoryViewModelFactory2 {
    let chainAsset: ChainAsset
    let balanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let assets: [WalletAsset]
    var chainFormat: ChainFormat { chainAsset.chain.chainFormat }
    let iconGenerator = PolkadotIconGenerator()

    init(
        chainAsset: ChainAsset,
        balanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        dateFormatter: LocalizableResource<DateFormatter>,
        assets: [WalletAsset]
    ) {
        self.chainAsset = chainAsset
        self.balanceFormatterFactory = balanceFormatterFactory
        self.dateFormatter = dateFormatter
        self.assets = assets
    }

    private func createTransferItemFromData(
        _ data: AssetTransactionData,
        locale: Locale,
        txType: TransactionType
    ) throws -> TransactionItemViewModel {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            throw TransactionHistoryViewModelFactoryError.missingAsset
        }

        let assetDisplayInfo = AssetBalanceDisplayInfo.fromWallet(asset: asset)
        let amount = balanceFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
            .value(for: locale)
            .stringFromDecimal(data.amount.decimalValue)
            ?? ""

        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let icon = txType == .incoming ? R.image.iconIncomingTransfer() : R.image.iconOutgoingTransfer()
        let imageViewModel = icon.map { StaticImageViewModel(image: $0) }
        let subtitle = R.string.localizable.transferTitle(preferredLanguages: locale.rLanguages)

        return TransactionItemViewModel(
            timestamp: timestamp,
            title: data.peerName ?? "",
            subtitle: subtitle,
            time: time,
            amount: amount,
            type: txType,
            status: data.status,
            imageViewModel: imageViewModel
        )
    }

    private func createRewardOrSlashItemFromData(
        _ data: AssetTransactionData,
        locale: Locale,
        txType: TransactionType
    ) throws -> TransactionItemViewModel {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            throw TransactionHistoryViewModelFactoryError.missingAsset
        }

        let assetDisplayInfo = AssetBalanceDisplayInfo.fromWallet(asset: asset)
        let amount = balanceFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
            .value(for: locale)
            .stringFromDecimal(data.amount.decimalValue)
            ?? ""

        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let icon = R.image.iconRewardOperation()
        let imageViewModel = icon.map { StaticImageViewModel(image: $0) }

        let title = txType == .reward ?
            R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages) :
            R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages)

        let subtitle = R.string.localizable.stakingTitle(preferredLanguages: locale.rLanguages)

        return TransactionItemViewModel(
            timestamp: timestamp,
            title: title,
            subtitle: subtitle,
            time: time,
            amount: amount,
            type: txType,
            status: data.status,
            imageViewModel: imageViewModel
        )
    }

    private func createExtrinsicItemFromData(
        _ data: AssetTransactionData,
        locale: Locale,
        txType: TransactionType
    ) throws -> TransactionItemViewModel {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            throw TransactionHistoryViewModelFactoryError.missingAsset
        }

        let assetDisplayInfo = AssetBalanceDisplayInfo.fromWallet(asset: asset)
        let amount = balanceFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
            .value(for: locale)
            .stringFromDecimal(data.amount.decimalValue)
            ?? ""

        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let iconUrl = chainAsset.asset.icon ?? chainAsset.chain.icon
        let imageViewModel: ImageViewModelProtocol = RemoteImageViewModel(url: iconUrl)

        return TransactionItemViewModel(
            timestamp: timestamp,
            title: data.peerLastName?.displayCall ?? "",
            subtitle: data.peerFirstName?.displayModule ?? "",
            time: time,
            amount: amount,
            type: txType,
            status: data.status,
            imageViewModel: imageViewModel
        )
    }
}

extension TransactionHistoryViewModelFactory2: TransactionHistoryViewModelFactory2Protocol {
    func createGroupModel(_ data: [AssetTransactionData], locale: Locale) throws -> [String: [TransactionItemViewModel]] {
        let items = try data.map { try self.createItemFromData($0, locale: locale) }
        return Dictionary(grouping: items, by: {
            let eventDate = Date(timeIntervalSince1970: TimeInterval($0.timestamp))
            return dateFormatter.value(for: locale).string(from: eventDate)
        })
    }

    func createItemFromData(
        _ data: AssetTransactionData,
        locale: Locale
    ) throws -> TransactionItemViewModel {
        guard let transactionType = TransactionType(rawValue: data.type) else {
            throw TransactionHistoryViewModelFactoryError.unsupportedType
        }

        switch transactionType {
        case .incoming, .outgoing:
            return try createTransferItemFromData(
                data,
                locale: locale,
                txType: transactionType
            )
        case .reward, .slash:
            return try createRewardOrSlashItemFromData(
                data,
                locale: locale,
                txType: transactionType
            )
        case .extrinsic:
            return try createExtrinsicItemFromData(
                data,
                locale: locale,
                txType: transactionType
            )
        }
    }
}
