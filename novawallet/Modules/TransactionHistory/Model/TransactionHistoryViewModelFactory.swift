import Foundation_iOS
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
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    let iconGenerator = PolkadotIconGenerator()
    let calendar = Calendar.current
    let dateFormatter: LocalizableResource<DateFormatter>
    var chainFormat: ChainFormat { chainAsset.chain.chainFormat }

    init(
        chainAsset: ChainAsset,
        dateFormatter: LocalizableResource<DateFormatter>,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        groupDateFormatter: LocalizableResource<DateFormatter>
    ) {
        self.chainAsset = chainAsset
        self.dateFormatter = dateFormatter
        self.balanceViewModelFactory = balanceViewModelFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory
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
            typeViewModel: .init(txType),
            status: data.status,
            imageViewModel: imageViewModel
        )
    }

    private func createSwapItemFromData(
        _ data: TransactionHistoryItem,
        priceCalculator: TokenPriceCalculatorProtocol?,
        locale: Locale,
        txType: TransactionType
    ) -> TransactionItemViewModel {
        let assetIn = chainAsset.chain.assetOrNil(for: data.swap?.assetIdIn)
        let assetOut = chainAsset.chain.assetOrNil(for: data.swap?.assetIdOut)
        let isOutgoing = assetIn?.assetId == chainAsset.asset.assetId
        let optAmountInPlank = isOutgoing ? data.swap?.amountIn : data.swap?.amountOut
        let amountInPlank = optAmountInPlank.map { BigUInt($0) ?? 0 } ?? 0
        let precision = (isOutgoing ? assetIn?.precision : assetOut?.precision) ?? 0
        let amount = Decimal.fromSubstrateAmount(
            amountInPlank,
            precision: Int16(precision)
        ) ?? .zero
        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))
        let balance = createBalance(
            from: amount,
            priceCalculator: priceCalculator,
            timestamp: data.timestamp,
            locale: locale
        )
        let icon = R.image.iconSwap()
        let imageViewModel = icon.map { StaticImageViewModel(image: $0) }
        let amountDetails = amountDetails(price: balance.price, time: time, locale: locale)
        let subtitle = [assetIn?.symbol, assetOut?.symbol].compactMap { $0 }.joined(separator: " → ")

        return .init(
            identifier: data.identifier,
            timestamp: data.timestamp,
            title: R.string.localizable.commonSwapTitle(preferredLanguages: locale.rLanguages),
            subtitle: subtitle,
            amount: balance.amount,
            amountDetails: amountDetails,
            typeViewModel: .init(txType, isIncome: !isOutgoing),
            status: data.status,
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

        guard let functionName = data.evmContractFunctionName else {
            let subtitle = R.string.localizable.walletHistoryTransferOutgoingDetails(
                data.receiver ?? "",
                preferredLanguages: locale.rLanguages
            )

            return .init(title: title, subtitle: subtitle)
        }

        if !functionName.hasAmbiguousFunctionName {
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
        let title = txType == .reward ?
            R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages) :
            R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages)
        let subtitle = R.string.localizable.stakingTitle(preferredLanguages: locale.rLanguages)

        return createCommonRewardItemFromData(
            data,
            title: title,
            subtitle: subtitle,
            priceCalculator: priceCalculator,
            locale: locale,
            txType: txType
        )
    }

    private func createPoolRewardOrSlashFromData(
        _ data: TransactionHistoryItem,
        priceCalculator: TokenPriceCalculatorProtocol?,
        locale: Locale,
        txType: TransactionType
    ) -> TransactionItemViewModel {
        let title = txType == .poolReward ?
            R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages) :
            R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages)
        let subtitle = R.string.localizable.stakingTypeNominationPool(preferredLanguages: locale.rLanguages)

        return createCommonRewardItemFromData(
            data,
            title: title,
            subtitle: subtitle,
            priceCalculator: priceCalculator,
            locale: locale,
            txType: txType
        )
    }

    private func createCommonRewardItemFromData(
        _ data: TransactionHistoryItem,
        title: String,
        subtitle: String,
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
        let amountDetails = amountDetails(price: balance.price, time: time, locale: locale)

        return TransactionItemViewModel(
            identifier: data.identifier,
            timestamp: data.timestamp,
            title: title,
            subtitle: subtitle,
            amount: balance.amount,
            amountDetails: amountDetails,
            typeViewModel: .init(txType),
            status: data.status,
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

        let imageViewModel = assetIconViewModelFactory.createAssetIconViewModel(
            for: chainAsset.asset.icon,
            with: .white
        )
        let peerFirstName = data.callPath.callName.displayCall
        let peerLastName = data.callPath.moduleName.displayCall
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
            typeViewModel: .init(txType),
            status: data.status,
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
        guard let transactionType = data.type(for: address, chainAssetId: chainAsset.chainAssetId) else {
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
        case .swap:
            return createSwapItemFromData(
                data,
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
        case .poolReward, .poolSlash:
            return createPoolRewardOrSlashFromData(
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
    func type(for address: AccountAddress, chainAssetId: ChainAssetId) -> TransactionType? {
        if swap != nil {
            return .swap
        }

        switch callPath {
        case .slash:
            return .slash
        case .reward:
            return .reward
        case .poolReward:
            return .poolReward
        case .poolSlash:
            return .poolSlash
        default:
            if
                callPath.isSubstrateOrEvmTransfer,
                chainAssetId.chainId == chainId,
                chainAssetId.assetId == assetId {
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
