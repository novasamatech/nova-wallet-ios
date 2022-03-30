import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

enum TransactionHistoryViewModelFactoryError: Error {
    case missingAsset
    case unsupportedType
}

final class TransactionHistoryViewModelFactory {
    let chainAsset: ChainAsset
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let assets: [WalletAsset]

    var chainFormat: ChainFormat { chainAsset.chain.chainFormat }

    let iconGenerator = PolkadotIconGenerator()

    init(
        chainAsset: ChainAsset,
        amountFormatterFactory: NumberFormatterFactoryProtocol,
        dateFormatter: LocalizableResource<DateFormatter>,
        assets: [WalletAsset]
    ) {
        self.chainAsset = chainAsset
        self.amountFormatterFactory = amountFormatterFactory
        self.dateFormatter = dateFormatter
        self.assets = assets
    }

    private func createTransferItemFromData(
        _ data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale,
        txType: TransactionType
    ) throws -> WalletViewModelProtocol {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            throw TransactionHistoryViewModelFactoryError.missingAsset
        }

        let amount = amountFormatterFactory.createTokenFormatter(for: asset)
            .value(for: locale)
            .stringFromDecimal(data.amount.decimalValue)
            ?? ""

        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let icon = txType == .incoming ? R.image.iconIncomingTransfer() : R.image.iconOutgoingTransfer()

        let imageViewModel = icon.map { StaticImageViewModel(image: $0) }

        let command = OperationDetailsCommand(
            commandFactory: commandFactory,
            txData: data,
            chainAsset: chainAsset
        )

        let subtitle = R.string.localizable.transferTitle(preferredLanguages: locale.rLanguages)

        return HistoryItemViewModel(
            title: data.peerName ?? "",
            subtitle: subtitle,
            amount: amount,
            time: time,
            type: txType,
            status: data.status,
            imageViewModel: imageViewModel,
            command: command
        )
    }

    private func createRewardOrSlashItemFromData(
        _ data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale,
        txType: TransactionType
    ) throws -> WalletViewModelProtocol {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            throw TransactionHistoryViewModelFactoryError.missingAsset
        }

        let amount = amountFormatterFactory.createTokenFormatter(for: asset)
            .value(for: locale)
            .stringFromDecimal(data.amount.decimalValue)
            ?? ""

        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let icon = R.image.iconRewardOperation()
        let imageViewModel = icon.map { StaticImageViewModel(image: $0) }

        let command = OperationDetailsCommand(
            commandFactory: commandFactory,
            txData: data,
            chainAsset: chainAsset
        )

        let title = txType == .reward ?
            R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages) :
            R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages)

        let subtitle = R.string.localizable.stakingTitle(preferredLanguages: locale.rLanguages)

        return HistoryItemViewModel(
            title: title,
            subtitle: subtitle,
            amount: amount,
            time: time,
            type: txType,
            status: data.status,
            imageViewModel: imageViewModel,
            command: command
        )
    }

    private func createExtrinsicItemFromData(
        _ data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale,
        txType: TransactionType
    ) throws -> WalletViewModelProtocol {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            throw TransactionHistoryViewModelFactoryError.missingAsset
        }

        let amount = amountFormatterFactory.createTokenFormatter(for: asset)
            .value(for: locale)
            .stringFromDecimal(data.amount.decimalValue)
            ?? ""

        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let iconUrl = chainAsset.chain.icon
        let imageViewModel: ImageViewModelProtocol = RemoteImageViewModel(url: iconUrl)

        let command = OperationDetailsCommand(
            commandFactory: commandFactory,
            txData: data,
            chainAsset: chainAsset
        )

        return HistoryItemViewModel(
            title: data.peerLastName?.displayCall ?? "",
            subtitle: data.peerFirstName?.displayModule ?? "",
            amount: amount,
            time: time,
            type: txType,
            status: data.status,
            imageViewModel: imageViewModel,
            command: command
        )
    }
}

extension TransactionHistoryViewModelFactory: HistoryItemViewModelFactoryProtocol {
    func createItemFromData(
        _ data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) throws -> WalletViewModelProtocol {
        guard let transactionType = TransactionType(rawValue: data.type) else {
            throw TransactionHistoryViewModelFactoryError.unsupportedType
        }

        switch transactionType {
        case .incoming, .outgoing:
            return try createTransferItemFromData(
                data,
                commandFactory: commandFactory,
                locale: locale,
                txType: transactionType
            )
        case .reward, .slash:
            return try createRewardOrSlashItemFromData(
                data,
                commandFactory: commandFactory,
                locale: locale,
                txType: transactionType
            )
        case .extrinsic:
            return try createExtrinsicItemFromData(
                data,
                commandFactory: commandFactory,
                locale: locale,
                txType: transactionType
            )
        }
    }
}
