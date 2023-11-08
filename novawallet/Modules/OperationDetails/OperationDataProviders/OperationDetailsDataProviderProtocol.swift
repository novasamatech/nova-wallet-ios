import Foundation
import BigInt

protocol OperationDetailsDataProviderProtocol {
    func extractOperationData(
        replacingWith newFee: BigUInt?,
        calculatorFactory: CalculatorFactoryProtocol,
        progressClosure: @escaping (OperationDetailsModel.OperationData?) -> Void
    )
}
