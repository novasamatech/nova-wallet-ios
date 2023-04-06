enum KiltTransferAssetRecipientError: Error {
    case verificationFailed
    case fileNotFound
    case corruptedData
    case decodingDataFailed(Error)
}
