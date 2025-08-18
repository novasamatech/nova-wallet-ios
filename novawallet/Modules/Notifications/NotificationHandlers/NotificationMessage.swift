import Foundation

enum NotificationMessage {
    case transfer(
        type: PushNotification.TransferType,
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
    case newMultisig(
        chainId: ChainModel.Id,
        payload: NewMultisigPayload
    )
    case newRelease(
        payload: NewReleasePayload
    )
}

extension NotificationMessage {
    init(userInfo: [AnyHashable: Any], decoder: JSONDecoder) throws {
        guard let type = userInfo["type"] as? String,
              let payloadString = userInfo["payload"] as? String,
              let payloadData = payloadString.replacingOccurrences(of: "'", with: "\"").data(using: .utf8) else {
            throw NotificationMessageError.invalidData
        }

        switch type {
        case "tokenSent":
            let chainId = userInfo["chainId"] as? String ?? ""
            let payload = try decoder.decode(NotificationTransferPayload.self, from: payloadData)
            self = .transfer(
                type: .outcome,
                chainId: chainId,
                payload: payload
            )
        case "tokenReceived":
            let chainId = userInfo["chainId"] as? String ?? ""
            let payload = try decoder.decode(NotificationTransferPayload.self, from: payloadData)
            self = .transfer(
                type: .income,
                chainId: chainId,
                payload: payload
            )
        case "govNewRef":
            let chainId = userInfo["chainId"] as? String ?? ""
            let payload = try decoder.decode(NewReferendumPayload.self, from: payloadData)
            self = .newReferendum(chainId: chainId, payload: payload)
        case "govState":
            let chainId = userInfo["chainId"] as? String ?? ""
            let payload = try decoder.decode(ReferendumStateUpdatePayload.self, from: payloadData)
            self = .referendumUpdate(chainId: chainId, payload: payload)
        case "stakingReward":
            let chainId = userInfo["chainId"] as? String ?? ""
            let payload = try decoder.decode(StakingRewardPayload.self, from: payloadData)
            self = .stakingReward(chainId: chainId, payload: payload)
        case "newMultisig":
            let chainId = userInfo["chainId"] as? String ?? ""
            let payload = try decoder.decode(NewMultisigPayload.self, from: payloadData)
            self = .newMultisig(chainId: chainId, payload: payload)
        case "appNewRelease":
            let payload = try decoder.decode(NewReleasePayload.self, from: payloadData)
            self = .newRelease(payload: payload)
        default:
            throw NotificationMessageError.invalidData
        }
    }
}

enum NotificationMessageError: Error {
    case invalidData
}
