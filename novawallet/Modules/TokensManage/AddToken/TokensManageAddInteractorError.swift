import Foundation

enum TokensManageAddInteractorError {
    case evmDetailsFetchFailed(_ internalError: Error)
    case priceIdProcessingFailed(_ internalError: Error)
}
