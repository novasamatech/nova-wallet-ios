import Foundation

enum ParaStkYieldBoostStopError: Error {
    case yieldBoostStopFailed(_ internalError: Error)
}
