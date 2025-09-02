import Foundation
import Foundation_iOS

struct SwapFeeDetailsViewFactory {
    static func createView(
        for operations: [AssetExchangeMetaOperationProtocol],
        fee: AssetExchangeFee,
        state: SwapTokensFlowStateProtocol
    ) -> SwapFeeDetailsViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let viewModelFactory = SwapFeeDetailsViewModelFactory(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager),
            priceStore: state.priceStore
        )

        let presenter = SwapFeeDetailsPresenter(
            operations: operations,
            fee: fee,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = SwapFeeDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
