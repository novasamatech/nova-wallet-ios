import Foundation
import SubstrateSdk

struct PolkadotExtensionMessage: Decodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case messageType = "msgType"
        case request
        case url
    }

    enum MessageType: String, Decodable {
        case authorize = "pub(authorize.tab)"
        case accountList = "pub(accounts.list)"
        case accountSubscribe = "pub(accounts.subscribe)"
        case metadataList = "pub(metadata.list)"
        case metadataProvide = "pub(metadata.provide)"
        case signBytes = "pub(bytes.sign)"
        case signExtrinsic = "pub(extrinsic.sign)"
    }

    let identifier: String
    let messageType: MessageType
    let request: JSON?
    let url: String?
}
