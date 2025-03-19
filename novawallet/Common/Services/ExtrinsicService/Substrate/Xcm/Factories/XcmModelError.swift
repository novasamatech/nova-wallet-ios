import Foundation

enum XcmModelError: Error {
    case noDestinationAssetFound(ChainAssetId)
    case noReserve(ChainAssetId)
    case unsupportedInstruction(String)
}
