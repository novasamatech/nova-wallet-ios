import Foundation
import CommonWallet

final class TransactionDetailsConfigurator {
    let viewModelFactory: TransactionDetailsViewModelFactory

    init(
        chainAccount: ChainAccountResponse,
        selectedAsset: AssetModel,
        utilityAsset: AssetModel,
        explorers: [ChainModel.Explorer]?
    ) {
        let amountViewModelFactory = BalanceViewModelFactory(targetAssetInfo: selectedAsset.displayInfo)

        let feeViewModelFactory: BalanceViewModelFactoryProtocol?

        if selectedAsset.assetId != utilityAsset.assetId {
            feeViewModelFactory = BalanceViewModelFactory(targetAssetInfo: utilityAsset.displayInfo)
        } else {
            feeViewModelFactory = nil
        }

        viewModelFactory = TransactionDetailsViewModelFactory(
            chainAccount: chainAccount,
            selectedAsset: selectedAsset,
            utilityAsset: utilityAsset,
            explorers: explorers,
            amountViewModelFactory: amountViewModelFactory,
            feeViewModelFactory: feeViewModelFactory,
            dateFormatter: DateFormatter.txDetails,
            integerFormatter: NumberFormatter.quantity.localizableResource()
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
