import Foundation
import BigInt

struct FeeOutputModel {
    let value: BigUInt
    let validationProvider: ExtrinsicValidationProviderProtocol?
}
