import Foundation

enum TokensManageAddInteractorError: Error {
    case evmDetailsFetchFailed(_ internalError: Error)
    case priceIdProcessingFailed
    case tokenAlreadyExists(AssetModel)
    case tokenSaveFailed(_ internalError: Error)
    case contractNotExists(chain: ChainModel)
}
