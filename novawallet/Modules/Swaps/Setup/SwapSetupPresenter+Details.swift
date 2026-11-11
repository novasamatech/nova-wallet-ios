import Foundation

extension SwapSetupPresenter {
    func showFeeInfo() {
        guard let quote, let fee else {
            return
        }

        wireframe.showFeeDetails(
            from: view,
            operations: quote.metaOperations,
            fee: fee
        )
    }

    func showRateInfo() {
        wireframe.showRateInfo(
            from: view,
            commissionRate: chargesCommission ? AssetExchangeCommissionConstants.rate : nil
        )
    }

    func showRouteDetails() {
        guard let quote, let fee else {
            return
        }

        wireframe.showRouteDetails(
            from: view,
            quote: quote,
            fee: fee
        )
    }
}
