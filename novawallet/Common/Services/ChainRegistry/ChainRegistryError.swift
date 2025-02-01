import Foundation

enum ChainRegistryError: Error {
    case connectionUnavailable(ChainModel.Id)
    case runtimeMetadaUnavailable(ChainModel.Id)
    case noChain(ChainModel.Id)
    case noChainAsset(ChainAssetId)
    case noUtilityAsset(ChainModel.Id)
}

extension ChainRegistryError: ErrorContentConvertible {
    private func deriveErrorMessage() -> String {
        // no need to localize since this is more for testing

        switch self {
        case let .connectionUnavailable(chainId):
            "No connection for \(chainId)"
        case let .runtimeMetadaUnavailable(chainId):
            "No metadata for \(chainId)"
        case let .noChain(chainId):
            "No chain info for \(chainId)"
        case let .noChainAsset(chainAssetId):
            "No asset \(chainAssetId.assetId) found for chain \(chainAssetId.chainId)"
        case let .noUtilityAsset(chainId):
            "No native asset found for \(chainId)"
        }
    }

    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let message = deriveErrorMessage()

        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)

        return ErrorContent(title: title, message: message)
    }
}
