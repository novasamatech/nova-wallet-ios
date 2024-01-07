import Foundation
import BigInt

struct FeeOutputModel {
    let value: ExtrinsicFeeProtocol
    let validationProvider: ExtrinsicValidationProviderProtocol?
}
