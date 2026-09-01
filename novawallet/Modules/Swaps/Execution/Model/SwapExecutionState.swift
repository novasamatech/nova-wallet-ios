import Foundation
import Foundation_iOS

enum SwapExecutionState {
    struct Failure {
        let operationIndex: Int
        let date: Date
        let error: Error
    }

    case inProgress(Int)
    case completed(Date)
    case failed(Failure)
}

extension SwapExecutionState.Failure {
    func getErrorDetails(for locale: Locale) -> String? {
        if let verificationError = error as? XcmTransferVerifierError {
            return switch verificationError {
            case .verificationFailed:
                R.string(preferredLanguages: locale.rLanguages).localizable.swapDryRunFailedInlineMessage()
            }
        }

        if let dispatchError = error as? DispatchCallError {
            return dispatchError.toErrorContent(for: locale).message
        }

        return nil
    }
}
