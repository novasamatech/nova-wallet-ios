enum AssetReceiveInteractorError: Error {
    case missingAccount
    case encodingData
    case generatingQRCode
}
