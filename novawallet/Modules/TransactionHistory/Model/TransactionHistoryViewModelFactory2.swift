import SoraFoundation
import SubstrateSdk
import BigInt

// TODO: Rename
protocol TransactionHistoryViewModelFactory2Protocol {
    func createItemFromData(
        _ data: TransactionHistoryItem,
        address: AccountAddress,
        locale: Locale
    ) -> TransactionItemViewModel?

    func createGroupModel(
        _ data: [TransactionHistoryItem],
        address: AccountAddress,
        locale: Locale
    ) -> [Date: [TransactionItemViewModel]]

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
        dateFormatter: DateFormatter,
        groupDateFormatter: DateFormatter
    ) {
        self.chainAsset = chainAsset
        self.tokenFormatter = tokenFormatter
        self.dateFormatter = dateFormatter.localizableResource()
        self.groupDateFormatter = groupDateFormatter.localizableResource()
    }

    private func createTransferItemFromData(
        _ data: TransactionHistoryItem,
        address: AccountAddress,
        locale: Locale,
        txType: TransactionType
    ) -> TransactionItemViewModel {
        let amountInPlank = data.amountInPlank.map { BigUInt($0) ?? 0 } ?? 0
        let amount = Decimal.fromSubstrateAmount(
            amountInPlank,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? .zero
        let formattedAmount = tokenFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let icon = txType == .incoming ? R.image.iconIncomingTransfer() : R.image.iconOutgoingTransfer()
        let imageViewModel = icon.map { StaticImageViewModel(image: $0) }
        let subtitle = R.string.localizable.transferTitle(preferredLanguages: locale.rLanguages)
        let peerAddress = (data.sender == address ? data.receiver : data.sender) ?? data.sender

        return TransactionItemViewModel(
            identifier: data.identifier,
            timestamp: data.timestamp,
            title: peerAddress,
            subtitle: subtitle,
            time: time,
            amount: formattedAmount,
            type: txType,
            status: data.status.walletValue,
            imageViewModel: imageViewModel
        )
    }

    private func createRewardOrSlashItemFromData(
        _ data: TransactionHistoryItem,
        locale: Locale,
        txType: TransactionType
    ) -> TransactionItemViewModel {
        let amountInPlank = data.amountInPlank.map { BigUInt($0) ?? 0 } ?? 0
        let amount = Decimal.fromSubstrateAmount(
            amountInPlank,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? .zero
        let formattedAmount = tokenFormatter.value(for: locale).stringFromDecimal(amount)
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
            identifier: data.identifier,
            timestamp: data.timestamp,
            title: title,
            subtitle: subtitle,
            time: time,
            amount: formattedAmount,
            type: txType,
            status: data.status.walletValue,
            imageViewModel: imageViewModel
        )
    }

    private func createExtrinsicItemFromData(
        _ data: TransactionHistoryItem,
        locale: Locale,
        txType: TransactionType
    ) -> TransactionItemViewModel {
        let feeValue = data.fee.map { BigUInt($0) ?? 0 } ?? 0
        let amount = Decimal.fromSubstrateAmount(
            feeValue,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? .zero
        let formattedAmount = tokenFormatter.value(for: locale).stringFromDecimal(amount)
            ?? ""
        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let iconUrl = chainAsset.asset.icon ?? chainAsset.chain.icon
        let imageViewModel: ImageViewModelProtocol = RemoteImageViewModel(url: iconUrl)
        let peerFirstName = data.callPath.moduleName.displayCall
        let peerLastName = data.callPath.callName.displayCall

        return TransactionItemViewModel(
            identifier: data.identifier,
            timestamp: data.timestamp,
            title: peerFirstName,
            subtitle: peerLastName,
            time: time,
            amount: formattedAmount,
            type: txType,
            status: data.status.walletValue,
            imageViewModel: imageViewModel
        )
    }
}

extension TransactionHistoryViewModelFactory2: TransactionHistoryViewModelFactory2Protocol {
    func formatHeader(date: Date, locale: Locale) -> String {
        groupDateFormatter.value(for: locale).string(from: date)
    }

    func createGroupModel(
        _ data: [TransactionHistoryItem],
        address: AccountAddress,
        locale: Locale
    ) -> [Date: [TransactionItemViewModel]] {
        let items = data.compactMap {
            createItemFromData($0, address: address, locale: locale)
        }

        let sections = Dictionary(grouping: items, by: {
            let eventDateTime = Date(timeIntervalSince1970: TimeInterval($0.timestamp))
            let eventDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: eventDateTime)!
            return eventDate
        })

        return sections
    }

    func createItemFromData(
        _ data: TransactionHistoryItem,
        address: AccountAddress,
        locale: Locale
    ) -> TransactionItemViewModel? {
        guard let transactionType = data.type(for: address) else {
            return nil
        }
        switch transactionType {
        case .incoming, .outgoing:
            return createTransferItemFromData(
                data,
                address: address,
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

extension TransactionHistoryItem {
    func type(for address: AccountAddress) -> TransactionType? {
        switch callPath {
        case .slash:
            return .slash
        case .reward:
            return .reward
        default:
            if callPath.isTransfer {
                return sender == address ? .outgoing : .incoming
            } else {
                return TransactionType.extrinsic
            }
        }
    }
}
