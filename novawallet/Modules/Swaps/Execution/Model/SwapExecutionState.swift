import Foundation
import Foundation_iOS

enum SwapExecutionState {
    case inProgress(Int)
    case completed(Date)
    case failed(Int, Date)
}
