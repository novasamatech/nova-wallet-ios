import BigInt

struct NotificationTransferPayload: Codable {
    let sender: AccountAddress
    let recipient: AccountAddress
    let amount: BigUInt
    let assetId: String
}
