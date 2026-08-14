import Foundation

typealias SwapInterEDCheckClosure = (SwapInterEDNotMet?) -> Void

struct SwapInterEDNotMet {
    let operationIndex: Int
    let comparedAmount: Balance
    let minBalanceResult: Result<Balance, Error>
}
