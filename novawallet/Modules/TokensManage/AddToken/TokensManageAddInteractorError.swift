import Foundation

enum TokensManageAddInteractorError {
    case evmDetailsFetchFailed(_ internalError: Error)
    case priceIdProcessingFailed
    case tokenAlreadyExists
    case tokenSaveFailed(_ internalError: Error)
}
