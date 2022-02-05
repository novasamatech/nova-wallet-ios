import Foundation

enum DAppSigningType {
    case extrinsic
    case bytes

    var msgType: PolkadotExtensionMessage.MessageType {
        switch self {
        case .extrinsic:
            return .signExtrinsic
        case .bytes:
            return .signBytes
        }
    }
}
