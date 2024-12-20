import Foundation
import SoraFoundation

enum SwapExecutionState {
    case inProgress(Int)
    case completed(Date)
    case failed(Int, Date)
}
