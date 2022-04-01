import Foundation
import CommonWallet
import SoraFoundation

final class TransactionHistoryConfigurator {
    private lazy var transactionCellStyle: TransactionCellStyleProtocol = {
        let title = WalletTextStyle(
            font: .semiBoldBody,
            color: R.color.colorWhite()!
        )
        let amount = WalletTextStyle(
            font: .p1Paragraph,
            color: R.color.colorWhite()!
        )
        let style = WalletTransactionStatusStyle(
            icon: nil,
            color: R.color.colorWhite()!
        )
        let container = WalletTransactionStatusStyleContainer(
            approved: style,
            pending: style,
            rejected: style
        )
        return TransactionCellStyle(
            backgroundColor: .clear,
            title: title,
            amount: amount,
            statusStyleContainer: container,
            increaseAmountIcon: nil,
            decreaseAmountIcon: nil,
            separatorColor: .clear
        )
    }()

    private lazy var headerStyle: TransactionHeaderStyleProtocol = {
        let title = WalletTextStyle(
            font: .semiBoldCaps2,
            color: R.color.colorTransparentText()!
        )
        return TransactionHeaderStyle(
            background: .clear,
            title: title,
            separatorColor: .clear,
            upppercased: true
        )
    }()

    let viewModelFactory: TransactionHistoryViewModelFactory

    let supportsFilters: Bool

    init(
        chainAsset: ChainAsset,
        amountFormatterFactory: NumberFormatterFactoryProtocol,
        assets: [WalletAsset]
    ) {
        supportsFilters = chainAsset.asset.assetId == chainAsset.chain.utilityAssets().first?.assetId

        viewModelFactory = TransactionHistoryViewModelFactory(
            chainAsset: chainAsset,
            amountFormatterFactory: amountFormatterFactory,
            dateFormatter: DateFormatter.txHistory,
            assets: assets
        )
    }

    func configure(builder: HistoryModuleBuilderProtocol) {
        let title = LocalizableResource { locale in
            R.string.localizable
                .walletHistoryTitle_v190(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(itemViewModelFactory: viewModelFactory)
            .with(emptyStateDataSource: WalletEmptyStateDataSource.history)
            .with(historyViewStyle: HistoryViewStyle.fearless)
            .with(transactionCellStyle: transactionCellStyle)
            .with(cellClass: HistoryItemTableViewCell.self, for: HistoryConstants.historyCellId)
            .with(transactionHeaderStyle: headerStyle)
            .with(includesFeeInAmount: false)
            .with(localizableTitle: title)
            .with(viewFactoryOverriding: WalletHistoryViewFactoryOverriding())

        if supportsFilters {
            builder
                .with(supportsFilter: true)
                .with(filterEditor: WalletHistoryFilterEditor())
        } else {
            builder.with(supportsFilter: false)
        }
    }
}
