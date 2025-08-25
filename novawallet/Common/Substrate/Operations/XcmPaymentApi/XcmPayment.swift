import Foundation
import SubstrateSdk

enum XcmPayment {
    static let apiName = "XcmPaymentApi"

    typealias WeightResult = Substrate.Result<Substrate.WeightV2, JSON>
}
