enum AssetDetailsHandlingError: Error {
    case invalidAssetId
    case select(Error)
    case unknownWallet
    case invalidAddress
    case unsupportedMessage
}
