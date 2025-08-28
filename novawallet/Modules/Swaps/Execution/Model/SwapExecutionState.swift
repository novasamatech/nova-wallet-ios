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
        guard let verificationError = error as? XcmTransferVerifierError else {
            return nil
        }

        return switch verificationError {
        case .verificationFailed:
            R.string.localizable.swapDryRunFailedInlineMessage(preferredLanguages: locale.rLanguages)
        }
    }
}
