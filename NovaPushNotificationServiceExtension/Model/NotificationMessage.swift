enum NotificationMessage {
    case transfer(
        type: TransferType,
        chainId: ChainModel.Id,
        payload: NotificationTransferPayload
    )
    case newReferendum(
        chainId: ChainModel.Id,
        payload: NewReferendumPayload
    )
    case referendumUpdate(
        chainId: ChainModel.Id,
        payload: ReferendumStateUpdatePayload
    )
    case stakingReward(
        chainId: ChainModel.Id,
        payload: StakingRewardPayload
    )
    case newRelease(
        payload: NewReleasePayload
    )
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
            self = .transfer(
                type: .outcome,
                chainId: chainId,
                payload: payload
            )
        case "tokensReceived":
            let chainId = try container.decode(String.self, forKey: .chainId)
            let payload = try container.decode(NotificationTransferPayload.self, forKey: .payload)
            self = .transfer(
                type: .income,
                chainId: chainId,
                payload: payload
            )
        case "govNewRef":
            let chainId = try container.decode(String.self, forKey: .chainId)
            let payload = try container.decode(NewReferendumPayload.self, forKey: .payload)
            self = .newReferendum(chainId: chainId, payload: payload)
        case "govState":
            let chainId = try container.decode(String.self, forKey: .chainId)
            let payload = try container.decode(ReferendumStateUpdatePayload.self, forKey: .payload)
            self = .referendumUpdate(chainId: chainId, payload: payload)
        case "stakingReward":
            let chainId = try container.decode(String.self, forKey: .chainId)
            let payload = try container.decode(StakingRewardPayload.self, forKey: .payload)
            self = .stakingReward(chainId: chainId, payload: payload)
        case "appNewRelease":
            let payload = try container.decode(NewReleasePayload.self, forKey: .payload)
            self = .newRelease(payload: payload)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "unexpected value"
            )
        }
    }
}
