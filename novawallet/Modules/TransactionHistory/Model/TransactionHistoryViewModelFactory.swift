import SoraFoundation
import SubstrateSdk
import BigInt

protocol TransactionHistoryViewModelFactoryProtocol {
    func createItemFromData(
        _ data: TransactionHistoryItem,
        priceCalculator: TokenPriceCalculatorProtocol?,
        address: AccountAddress,
        locale: Locale
    ) -> TransactionItemViewModel?

    func createGroupModel(
        _ data: [TransactionHistoryItem],
        priceCalculator: TokenPriceCalculatorProtocol?,
        address: AccountAddress,
        locale: Locale
    ) -> [Date: [TransactionItemViewModel]]

    func formatHeader(date: Date, locale: Locale) -> String
}

final class TransactionHistoryViewModelFactory {
    let chainAsset: ChainAsset
    let groupDateFormatter: LocalizableResource<DateFormatter>
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let iconGenerator = PolkadotIconGenerator()
    let calendar = Calendar.current

    var chainFormat: ChainFormat { chainAsset.chain.chainFormat }

    init(
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        groupDateFormatter: LocalizableResource<DateFormatter>
    ) {
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.groupDateFormatter = groupDateFormatter
    }

    private func createBalance(
        from amount: Decimal,
        priceCalculator: TokenPriceCalculatorProtocol?,
        timestamp: Int64,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let optPrice = priceCalculator?.calculatePrice(for: UInt64(bitPattern: timestamp))
        let priceData = optPrice.map { PriceData.amount($0) }
        return balanceViewModelFactory.balanceFromPrice(amount, priceData: priceData).value(for: locale)
    }

    private func createTransferItemFromData(
        _ data: TransactionHistoryItem,
        address: AccountAddress,
        priceCalculator: TokenPriceCalculatorProtocol?,
        locale: Locale,
        txType: TransactionType
    ) -> TransactionItemViewModel {
        let amountInPlank = data.amountInPlank.map { BigUInt($0) ?? 0 } ?? 0
        let amount = Decimal.fromSubstrateAmount(
            amountInPlank,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? .zero

        let balance = createBalance(
            from: amount,
            priceCalculator: priceCalculator,
            timestamp: data.timestamp,
            locale: locale
        )

        let icon = txType == .incoming ? R.image.iconIncomingTransfer() : R.image.iconOutgoingTransfer()
        let imageViewModel = icon.map { StaticImageViewModel(image: $0) }
        let subtitle = R.string.localizable.transferTitle(preferredLanguages: locale.rLanguages)
        let peerAddress = (data.sender == address ? data.receiver : data.sender) ?? data.sender

        return TransactionItemViewModel(
            identifier: data.identifier,
            timestamp: data.timestamp,
            title: peerAddress,
            subtitle: subtitle,
            time: balance.price ?? "",
            amount: balance.amount,
            type: txType,
            status: data.status.walletValue,
            imageViewModel: imageViewModel
        )
    }

    private func createRewardOrSlashItemFromData(
        _ data: TransactionHistoryItem,
        priceCalculator: TokenPriceCalculatorProtocol?,
        locale: Locale,
        txType: TransactionType
    ) -> TransactionItemViewModel {
        let amountInPlank = data.amountInPlank.map { BigUInt($0) ?? 0 } ?? 0
        let amount = Decimal.fromSubstrateAmount(
            amountInPlank,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? .zero

        let balance = createBalance(
            from: amount,
            priceCalculator: priceCalculator,
            timestamp: data.timestamp,
            locale: locale
        )

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
            time: balance.price ?? "",
            amount: balance.amount,
            type: txType,
            status: data.status.walletValue,
            imageViewModel: imageViewModel
        )
    }

    private func createExtrinsicItemFromData(
        _ data: TransactionHistoryItem,
        priceCalculator: TokenPriceCalculatorProtocol?,
        locale: Locale,
        txType: TransactionType
    ) -> TransactionItemViewModel {
        let feeValue = data.fee.map { BigUInt($0) ?? 0 } ?? 0
        let amount = Decimal.fromSubstrateAmount(
            feeValue,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? .zero

        let balance = createBalance(
            from: amount,
            priceCalculator: priceCalculator,
            timestamp: data.timestamp,
            locale: locale
        )

        let iconUrl = chainAsset.asset.icon ?? chainAsset.chain.icon
        let imageViewModel: ImageViewModelProtocol = RemoteImageViewModel(url: iconUrl)
        let peerFirstName = data.callPath.moduleName.displayCall
        let peerLastName = data.callPath.callName.displayCall

        return TransactionItemViewModel(
            identifier: data.identifier,
            timestamp: data.timestamp,
            title: peerFirstName,
            subtitle: peerLastName,
            time: balance.price ?? "",
            amount: balance.amount,
            type: txType,
            status: data.status.walletValue,
            imageViewModel: imageViewModel
        )
    }
}

extension TransactionHistoryViewModelFactory: TransactionHistoryViewModelFactoryProtocol {
    func formatHeader(date: Date, locale: Locale) -> String {
        groupDateFormatter.value(for: locale).string(from: date)
    }

    func createGroupModel(
        _ data: [TransactionHistoryItem],
        priceCalculator: TokenPriceCalculatorProtocol?,
        address: AccountAddress,
        locale: Locale
    ) -> [Date: [TransactionItemViewModel]] {
        let items = data.compactMap {
            createItemFromData(
                $0,
                priceCalculator: priceCalculator,
                address: address,
                locale: locale
            )
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
        priceCalculator: TokenPriceCalculatorProtocol?,
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
                priceCalculator: priceCalculator,
                locale: locale,
                txType: transactionType
            )
        case .reward, .slash:
            return createRewardOrSlashItemFromData(
                data,
                priceCalculator: priceCalculator,
                locale: locale,
                txType: transactionType
            )
        case .extrinsic:
            return createExtrinsicItemFromData(
                data,
                priceCalculator: priceCalculator,
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
            if callPath.isSubstrateOrEvmTransfer {
                return sender == address ? .outgoing : .incoming
            } else {
                return TransactionType.extrinsic
            }
        }
    }
}
