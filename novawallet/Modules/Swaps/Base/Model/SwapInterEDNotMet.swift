import Foundation

typealias SwapInterEDCheckClosure = (SwapInterEDNotMet?) -> Void

struct SwapInterEDNotMet {
    let operationIndex: Int
    let minBalanceResult: Result<Balance, Error>
}
