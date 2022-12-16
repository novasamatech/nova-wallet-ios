import SoraFoundation
import SubstrateSdk
import CommonWallet

protocol TransactionHistoryViewModelFactory2Protocol {
    func createItemFromData(
        _ data: AssetTransactionData,
        locale: Locale
    ) throws -> TransactionItemViewModel

    func createGroupModel(_ data: [AssetTransactionData], locale: Locale) throws -> [Date: [TransactionItemViewModel]]

    func formatHeader(date: Date, locale: Locale) -> String
}

final class TransactionHistoryViewModelFactory2 {
    let chainAsset: ChainAsset
    let dateFormatter: LocalizableResource<DateFormatter>
    let groupDateFormatter: LocalizableResource<DateFormatter>
    var chainFormat: ChainFormat { chainAsset.chain.chainFormat }
    let tokenFormatter: LocalizableResource<TokenFormatter>
    let iconGenerator = PolkadotIconGenerator()
    let calendar = Calendar.current

    init(
        chainAsset: ChainAsset,
        tokenFormatter: LocalizableResource<TokenFormatter>,
        dateFormatter: LocalizableResource<DateFormatter>,
        groupDateFormatter: LocalizableResource<DateFormatter>
    ) {
        self.chainAsset = chainAsset
        self.tokenFormatter = tokenFormatter
        self.dateFormatter = dateFormatter
        self.groupDateFormatter = groupDateFormatter
    }

    private func createTransferItemFromData(
        _ data: AssetTransactionData,
        locale: Locale,
        txType: TransactionType
    ) -> TransactionItemViewModel {
        let amount = tokenFormatter.value(for: locale).stringFromDecimal(data.amount.decimalValue) ?? ""

        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let icon = txType == .incoming ? R.image.iconIncomingTransfer() : R.image.iconOutgoingTransfer()
        let imageViewModel = icon.map { StaticImageViewModel(image: $0) }
        let subtitle = R.string.localizable.transferTitle(preferredLanguages: locale.rLanguages)

        return TransactionItemViewModel(
            timestamp: data.timestamp,
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
    ) -> TransactionItemViewModel {
        let amount = tokenFormatter.value(for: locale).stringFromDecimal(data.amount.decimalValue)
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
            timestamp: data.timestamp,
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
    ) -> TransactionItemViewModel {
        let amount = tokenFormatter.value(for: locale).stringFromDecimal(data.amount.decimalValue)
            ?? ""

        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let iconUrl = chainAsset.asset.icon ?? chainAsset.chain.icon
        let imageViewModel: ImageViewModelProtocol = RemoteImageViewModel(url: iconUrl)

        return TransactionItemViewModel(
            timestamp: data.timestamp,
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
    func formatHeader(date: Date, locale: Locale) -> String {
        groupDateFormatter.value(for: locale).string(from: date)
    }

    func createGroupModel(_ data: [AssetTransactionData], locale: Locale) throws ->
        [Date: [TransactionItemViewModel]] {
        let items = try data.map {
            try self.createItemFromData($0, locale: locale)
        }

        let sections = Dictionary(grouping: items, by: {
            let eventDateTime = Date(timeIntervalSince1970: TimeInterval($0.timestamp))
            let eventDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: eventDateTime)!
            return eventDate
        })

        return sections
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
            return createTransferItemFromData(
                data,
                locale: locale,
                txType: transactionType
            )
        case .reward, .slash:
            return createRewardOrSlashItemFromData(
                data,
                locale: locale,
                txType: transactionType
            )
        case .extrinsic:
            return createExtrinsicItemFromData(
                data,
                locale: locale,
                txType: transactionType
            )
        }
    }
}
