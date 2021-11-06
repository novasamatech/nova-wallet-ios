import Foundation
import CommonWallet

final class TransactionDetailsConfigurator {
    let viewModelFactory: TransactionDetailsViewModelFactory

    init(
        chainAccount: ChainAccountResponse,
        amountFormatterFactory: NumberFormatterFactoryProtocol,
        assets: [WalletAsset],
        explorers: [ChainModel.Explorer]?
    ) {
        viewModelFactory = TransactionDetailsViewModelFactory(
            chainAccount: chainAccount,
            explorers: explorers,
            assets: assets,
            dateFormatter: DateFormatter.txDetails,
            amountFormatterFactory: amountFormatterFactory
        )
    }

    func configure(builder: TransactionDetailsModuleBuilderProtocol) {
        builder
            .with(viewModelFactory: viewModelFactory)
            .with(viewBinder: TransactionDetailsFormViewModelBinder())
            .with(definitionFactory: WalletFearlessDefinitionFactory())
            .with(accessoryViewFactory: TransactionDetailsAccessoryViewFactory.self)
    }
}
