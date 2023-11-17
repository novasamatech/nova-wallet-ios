import Foundation
import BigInt

protocol OperationDetailsDataProviderProtocol {
    func extractOperationData(
        replacingWith newFee: BigUInt?,
        calculatorFactory: PriceHistoryCalculatorFactoryProtocol,
        progressClosure: @escaping (OperationDetailsModel.OperationData?) -> Void
    )
}
