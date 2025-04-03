import Foundation
import SubstrateSdk

enum XcmPayment {
    static let apiName = "XcmPaymentApi"

    typealias WeightResult = Substrate.Result<BlockchainWeight.WeightV2, JSON>
}
