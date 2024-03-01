enum NotificationMessage {
    case transfer(type: TransferType,
                  chainId: ChainModel.Id,
                  payload: NotificationTransferPayload)
}

extension NotificationMessage: Decodable {
    enum CodingKeys: CodingKey {
        case type
        case chainId
        case payload
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "tokensSent":
            let chainId = try container.decode(String.self, forKey: .chainId)
            let payload = try container.decode(NotificationTransferPayload.self, forKey: .payload)
            self = .transfer(type: .outcome,
                             chainId: chainId,
                             payload: payload)
        case "tokensReceived":
            let chainId = try container.decode(String.self, forKey: .chainId)
            let payload = try container.decode(NotificationTransferPayload.self, forKey: .payload)
            self = .transfer(type: .income,
                             chainId: chainId,
                             payload: payload)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "unexpected value"
            )
        }
    }
}
