enum OpenPushAssetError: Error {
    case invalidAssetId
    case select(Error)
    case unknownWallet
    case invalidAddress
    case internalError
}
