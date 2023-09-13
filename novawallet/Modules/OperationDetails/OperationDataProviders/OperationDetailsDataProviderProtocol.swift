import Foundation
import BigInt

protocol OperationDetailsDataProviderProtocol {
    func extractOperationData(
        replacingWith newFee: BigUInt?,
        priceCalculator: TokenPriceCalculatorProtocol?,
        feePriceCalculator: TokenPriceCalculatorProtocol?,
        progressClosure: @escaping (OperationDetailsModel.OperationData?) -> Void
    )
}
