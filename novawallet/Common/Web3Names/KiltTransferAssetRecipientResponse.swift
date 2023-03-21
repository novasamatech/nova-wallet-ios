typealias KiltTransferAssetRecipientResponse = [String: [KiltTransferAssetRecipientAccount]]

struct KiltTransferAssetRecipientAccount: Codable {
    let account: String
    let description: String?
}
