import Foundation

enum CommonMetadataShortenerError: Error {
    case metadataMissing
    case invalidMetadata(localVersion: UInt32, remoteVersion: UInt32)
    case invalidDecimals
    case missingNativeAsset
}
