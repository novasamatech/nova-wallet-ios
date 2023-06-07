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
    let dateFormatter: LocalizableResource<DateFormatter>

    var chainFormat: ChainFormat { chainAsset.chain.chainFormat }

    init(
        chainAsset: ChainAsset,
        dateFormatter: LocalizableResource<DateFormatter>,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        groupDateFormatter: LocalizableResource<DateFormatter>
    ) {
        self.chainAsset = chainAsset
        self.dateFormatter = dateFormatter
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
        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let balance = createBalance(
            from: amount,
            priceCalculator: priceCalculator,
            timestamp: data.timestamp,
            locale: locale
        )

        let icon = txType == .incoming ? R.image.iconIncomingTransfer() : R.image.iconOutgoingTransfer()
        let imageViewModel = icon.map { StaticImageViewModel(image: $0) }
        let amountDetails = amountDetails(price: balance.price, time: time, locale: locale)
        let itemTitleWithSubtitle = createTransferItemTitleWithSubtitle(
            data: data,
            address: address,
            txType: txType,
            locale: locale
        )

        return TransactionItemViewModel(
            identifier: data.identifier,
            timestamp: data.timestamp,
            title: itemTitleWithSubtitle.title,
            subtitle: itemTitleWithSubtitle.subtitle,
            amount: balance.amount,
            amountDetails: amountDetails,
            type: txType,
            status: data.status.walletValue,
            imageViewModel: imageViewModel
        )
    }

    private func createTransferItemTitleWithSubtitle(
        data: TransactionHistoryItem,
        address: AccountAddress,
        txType: TransactionType,
        locale: Locale
    ) -> TitleWithSubtitleViewModel {
        let peerAddress = (data.sender == address ? data.receiver : data.sender) ?? data.sender
        let title = R.string.localizable.transferTitle(preferredLanguages: locale.rLanguages)

        let subtitle = txType == .incoming ?
            R.string.localizable.walletHistoryTransferIncomingDetails(
                peerAddress,
                preferredLanguages: locale.rLanguages
            ) :
            R.string.localizable.walletHistoryTransferOutgoingDetails(
                peerAddress,
                preferredLanguages: locale.rLanguages
            )

        return .init(title: title, subtitle: subtitle)
    }

    private func createEvmContractCallTitleWithSubtitle(
        data: TransactionHistoryItem,
        locale: Locale
    ) -> TitleWithSubtitleViewModel {
        let title = R.string.localizable.evmContractCall(preferredLanguages: locale.rLanguages)

        if let functionName = data.evmContractFunctionName, functionName.hasAmbiguousFunctionName {
            return .init(title: title, subtitle: functionName)
        } else {
            let subtitle = R.string.localizable.walletHistoryTransferOutgoingDetails(
                data.receiver ?? "",
                preferredLanguages: locale.rLanguages
            )
            return .init(title: title, subtitle: subtitle)
        }
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
        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

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
        let amountDetails = amountDetails(price: balance.price, time: time, locale: locale)

        return TransactionItemViewModel(
            identifier: data.identifier,
            timestamp: data.timestamp,
            title: title,
            subtitle: subtitle,
            amount: balance.amount,
            amountDetails: amountDetails,
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
        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

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
        let extrinsicTitleWithSubtitle = data.callPath.isEvmNativeTransaction ?
            createEvmContractCallTitleWithSubtitle(data: data, locale: locale) :
            .init(title: peerFirstName, subtitle: peerLastName)
        let amountDetails = amountDetails(price: balance.price, time: time, locale: locale)

        return TransactionItemViewModel(
            identifier: data.identifier,
            timestamp: data.timestamp,
            title: extrinsicTitleWithSubtitle.title,
            subtitle: extrinsicTitleWithSubtitle.subtitle,
            amount: balance.amount,
            amountDetails: amountDetails,
            type: txType,
            status: data.status.walletValue,
            imageViewModel: imageViewModel
        )
    }

    private func amountDetails(price: String?, time: String, locale: Locale) -> String {
        guard let price = price else {
            return time
        }
        return R.string.localizable.walletHistoryAmountDetails(
            price,
            time,
            preferredLanguages: locale.rLanguages
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

    var evmContractFunctionName: String? {
        if let call = call,
           let functionName = String(data: call, encoding: .utf8),
           !functionName.isEmpty {
            return functionName.displayContractFunction
        } else {
            return nil
        }
    }
}
